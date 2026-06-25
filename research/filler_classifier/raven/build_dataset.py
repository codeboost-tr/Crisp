"""Raven Phase 1 — build per-filler, language-context training examples.

For every Uh/Um in the PodcastFillers episodes, emit one example carrying the thing
Wren never had — the **surrounding words** — plus the gap/VAD signals and a derived
removable label:

    {episode, split, filler, start, end, dur,
     words_before:[…last K spoken words…], words_after:[…first K…],
     gap_before, gap_after, sil_before, sil_after, removable}

The label is *derived* (no human gold exists): a filler is `removable` only if it's
detached on BOTH sides (a real word-gap OR a VAD pause) — the conservative rule the
v2/relabel work validated. Raven's bet is that a model over the **words** beats that
gap-only rule. The words + gaps come from the episode transcripts (Azure ASR,
word-level timing in 100-ns ticks) and VAD already on disk.

    python -m filler_classifier.raven.build_dataset --data data/PodcastFillers --out data/raven
"""
from __future__ import annotations

import argparse
import csv
import glob
import json
import os
import re
from bisect import bisect_left, bisect_right
from pathlib import Path

from ..v2.derive_labels import FILLERS, GAP_SEC, has_pause, load_vad

OFFSET_UNIT = 1e7    # Azure transcript offsets/durations are in 100-ns ticks → seconds
WORD_GAP = 0.20      # gap (s) to the nearest spoken word that counts as "detached"
CONTEXT_WORDS = 6    # how many neighbouring words to keep on each side
_PUNCT = re.compile(r"[^\w'-]")


def load_words(path: str):
    """Transcript JSON → list of (start, end, text) sorted by start, lower-cased."""
    try:
        d = json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return None
    words = []
    for seg in d.get("segments", []):
        for nb in (seg.get("nbest") or [])[:1]:            # top hypothesis only
            for w in nb.get("words", []):
                txt = _PUNCT.sub("", (w.get("text") or "").lower())
                if not txt:
                    continue
                s = w["offset"] / OFFSET_UNIT
                words.append((s, s + w.get("duration", 0) / OFFSET_UNIT, txt))
    words.sort()
    return words or None


def context(words, fs: float, fe: float):
    """Words before the filler start / after its end, plus the gap to each side."""
    starts = [w[0] for w in words]
    ends = [w[1] for w in words]
    i = bisect_right(ends, fs + 0.05)                      # words ending at/just before fs
    j = bisect_left(starts, fe - 0.05)                     # words starting at/just after fe
    before = [w[2] for w in words[max(0, i - CONTEXT_WORDS):i]]
    after = [w[2] for w in words[j:j + CONTEXT_WORDS]]
    gap_before = (fs - ends[i - 1]) if i > 0 else 99.0
    gap_after = (starts[j] - fe) if j < len(starts) else 99.0
    return before, after, max(0.0, gap_before), max(0.0, gap_after)


def run(data_dir, out_dir):
    meta = Path(data_dir) / "metadata"
    episodes = sorted(glob.glob(str(meta / "episode_annotations" / "*" / "*.csv")))
    if not episodes:
        raise SystemExit(f"No annotations under {meta}/episode_annotations.")
    Path(out_dir).mkdir(parents=True, exist_ok=True)

    files = {s: open(Path(out_dir) / f"raven_{s}.jsonl", "w")
             for s in ("train", "validation", "test")}
    counts = {s: [0, 0] for s in files}                    # [removable, total]
    n_tr = 0
    try:
        for ann in episodes:
            split = ann.split(os.sep)[-2]
            if split not in files:
                continue
            vad = load_vad(ann.replace("episode_annotations", "episode_vad"))
            tr = ann.replace("episode_annotations", "episode_transcripts")[:-4] + ".json"
            words = load_words(tr)
            n_tr += words is not None
            with open(ann) as f:
                for r in csv.DictReader(f):
                    if r["label_consolidated_vocab"] not in FILLERS:
                        continue
                    fs = float(r["event_start_inepisode"])
                    fe = float(r["event_end_inepisode"])
                    sil_b = has_pause(vad, fs - GAP_SEC, fs)
                    sil_a = has_pause(vad, fe, fe + GAP_SEC)
                    if words:
                        before, after, gb, ga = context(words, fs, fe)
                    else:                                  # no transcript → gaps from VAD only
                        before, after = [], []
                        gb = 99.0 if sil_b else 0.0
                        ga = 99.0 if sil_a else 0.0
                    removable = (gb >= WORD_GAP or sil_b) and (ga >= WORD_GAP or sil_a)
                    files[split].write(json.dumps({
                        "episode": Path(ann).stem, "split": split,
                        "filler": r["label_consolidated_vocab"], "start": fs, "end": fe,
                        "dur": round(fe - fs, 3), "words_before": before, "words_after": after,
                        "gap_before": round(gb, 3), "gap_after": round(ga, 3),
                        "sil_before": sil_b, "sil_after": sil_a, "removable": removable,
                    }) + "\n")
                    counts[split][0] += removable
                    counts[split][1] += 1
    finally:
        for f in files.values():
            f.close()

    print(f"built Raven dataset → {out_dir}  ({n_tr} episodes had transcripts)")
    for s, (rem, tot) in counts.items():
        if tot:
            print(f"  {s:11} {tot:6} fillers   removable {rem} ({100*rem/tot:.0f}%)")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--data", default="data/PodcastFillers")
    p.add_argument("--out", default="data/raven")
    a = p.parse_args()
    run(a.data, a.out)


if __name__ == "__main__":
    main()
