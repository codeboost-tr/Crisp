"""Raven — the heavier, language- and context-aware filler tier.

Wren (v1/v2) is fast and audio-only: it scores the *sound* of a moment, so it's
inherently a per-frame yes/no and can't tell a load-bearing mid-sentence "hmm" from
a removable one. Raven adds the missing signal — the **words**. It reads a
transcript (the bundled Whisper) and, for each filler, judges *removability from the
surrounding language*, not just the acoustics.

Pipeline (on-device, two-pass): Whisper transcript → for each filler (a word Whisper
tags as um/uh/hmm, or a Wren acoustic candidate) → a small removability head over the
neighbouring words + gaps → cut/keep. Whisper already transcribes "hmm/er/mm" as
words, so Raven gets variant coverage for free — no acoustic variant dataset needed.

Phases: build_dataset.py (per-filler word-context examples + derived label) →
train.py (the head; does language beat the gap-only rule?) → export/infer.
"""
