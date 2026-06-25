"""Raven Phase 2 — the removability head + the honest ablation.

A tiny model over a filler's CONTEXT decides removable vs natural:
  • words: neighbouring words (before/after) → embedding → masked mean-pool.
  • numeric: gap_before/after, sil_before/after, duration, is-Um.
  • → MLP → 1 logit.

Because the `removable` label is *gap-derived* (Phase 1 caveat), feeding the gaps in
is near-circular. So this trains THREE variants and prints all three, to answer the
only question that matters: **do the WORDS carry the signal, or just the gaps?**
  - gaps-only  → reproduces the timing rule (the ceiling/baseline).
  - words-only → can LANGUAGE alone predict removability? (Raven's whole premise.)
  - both       → does language add anything on top of the rule?

    python -m filler_classifier.raven.train --data data/raven --out checkpoints/raven_head.pt
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

import torch
from torch import nn

CTX = 6            # words kept per side (matches build_dataset CONTEXT_WORDS)
PAD, UNK = 0, 1


def load(path):
    return [json.loads(l) for l in open(path)]


def build_vocab(rows, max_size=3000):
    c = Counter()
    for r in rows:
        c.update(r["words_before"] + r["words_after"])
    vocab = {"<pad>": PAD, "<unk>": UNK}
    for w, _ in c.most_common(max_size):
        vocab[w] = len(vocab)
    return vocab


def vectorize(rows, vocab):
    n = len(rows)
    words = torch.full((n, 2 * CTX), PAD, dtype=torch.long)
    num = torch.zeros((n, 6), dtype=torch.float32)
    y = torch.zeros(n, dtype=torch.float32)
    for i, r in enumerate(rows):
        ctx = (r["words_before"][-CTX:] + ["<pad>"] * CTX)[:CTX] \
            + (r["words_after"][:CTX] + ["<pad>"] * CTX)[:CTX]
        words[i] = torch.tensor([vocab.get(w, UNK) if w != "<pad>" else PAD for w in ctx])
        num[i] = torch.tensor([min(r["gap_before"], 2.0), min(r["gap_after"], 2.0),
                               float(r["sil_before"]), float(r["sil_after"]),
                               min(r["dur"], 2.0), float(r["filler"] == "Um")])
    y = torch.tensor([float(r["removable"]) for r in rows])
    return words, num, y


class RavenHead(nn.Module):
    def __init__(self, vocab_size, emb=32, use_words=True, use_gaps=True):
        super().__init__()
        self.use_words, self.use_gaps = use_words, use_gaps
        self.embed = nn.Embedding(vocab_size, emb, padding_idx=PAD)
        in_dim = (emb if use_words else 0) + (6 if use_gaps else 0)
        self.mlp = nn.Sequential(nn.Linear(in_dim, 64), nn.ReLU(), nn.Linear(64, 1))

    def forward(self, words, num):
        parts = []
        if self.use_words:
            e = self.embed(words)                          # [B, 2CTX, emb]
            mask = (words != PAD).unsqueeze(-1).float()
            parts.append((e * mask).sum(1) / mask.sum(1).clamp(min=1))   # masked mean
        if self.use_gaps:
            parts.append(num)
        return self.mlp(torch.cat(parts, -1)).squeeze(-1)


@torch.no_grad()
def f1(model, words, num, y, thr=0.5):
    p = (torch.sigmoid(model(words, num)) >= thr).float()
    tp = ((p == 1) & (y == 1)).sum().item()
    fp = ((p == 1) & (y == 0)).sum().item()
    fn = ((p == 0) & (y == 1)).sum().item()
    prec = tp / (tp + fp) if tp + fp else 0.0
    rec = tp / (tp + fn) if tp + fn else 0.0
    return (2 * prec * rec / (prec + rec) if prec + rec else 0.0), prec, rec


def train_one(name, use_words, use_gaps, data, vocab, epochs, out=None):
    (wtr, ntr, ytr), (wva, nva, yva) = data
    torch.manual_seed(0)
    model = RavenHead(len(vocab), use_words=use_words, use_gaps=use_gaps)
    pos_w = (ytr == 0).sum() / (ytr == 1).sum().clamp(min=1)
    loss_fn = nn.BCEWithLogitsLoss(pos_weight=pos_w)
    opt = torch.optim.Adam(model.parameters(), lr=1e-3)
    best = (-1, 0, 0)
    idx = torch.arange(len(ytr))
    for _ in range(epochs):
        model.train()
        for b in idx.split(256):
            opt.zero_grad()
            loss = loss_fn(model(wtr[b], ntr[b]), ytr[b])
            loss.backward(); opt.step()
        model.eval()
        sc = f1(model, wva, nva, yva)
        if sc[0] > best[0]:
            best = sc
            if out:
                torch.save(model.state_dict(), out)
    print(f"  {name:11}  val F1={best[0]:.3f}  P={best[1]:.3f} R={best[2]:.3f}")
    return best


def run(data_dir, out, epochs):
    data_dir = Path(data_dir)
    tr_rows, va_rows = load(data_dir / "raven_train.jsonl"), load(data_dir / "raven_validation.jsonl")
    vocab = build_vocab(tr_rows)
    (Path(out).parent).mkdir(parents=True, exist_ok=True)
    json.dump(vocab, open(Path(out).with_suffix(".vocab.json"), "w"))
    data = (vectorize(tr_rows, vocab), vectorize(va_rows, vocab))
    print(f"train={len(tr_rows)}  val={len(va_rows)}  vocab={len(vocab)}\n"
          f"=== ablation: does LANGUAGE carry the signal? ===")
    train_one("gaps-only", False, True, data, vocab, epochs)            # the timing-rule ceiling
    train_one("words-only", True, False, data, vocab, epochs)           # Raven's premise
    train_one("both", True, True, data, vocab, epochs, out=out)         # the shipped head
    print(f"\nsaved head + vocab → {out}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--data", default="data/raven")
    p.add_argument("--out", default="checkpoints/raven_head.pt")
    p.add_argument("--epochs", type=int, default=25)
    a = p.parse_args()
    run(a.data, a.out, a.epochs)


if __name__ == "__main__":
    main()
