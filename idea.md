# Crisp — feature ideas / roadmap

Polish, speed, and stability ideas for the app. Grounded in the current
architecture (SwiftUI app driving the stdlib Python engine). Sequenced by
impact-per-effort. Living doc — add/reorder freely.

> Shipped ideas are pruned from this list once they land. Most recent removals:
> VFR handling (PR #77), Export to editor / FCPXML (PR #79), Quit guard during
> render (PR #80). See git history for the full record.

---

## 🎨 Polish (premium feel)

1. **Before/after preview of the *result*** — scrub/play the cleaned result (or A/B
   against the original) *before* writing the file. The "hear it before you commit"
   step. Reuses the review timeline + preview sheet + waveform.
   - **Partially shipped:** the review timeline can skip-play the *enabled* cuts so
     you experience the cleaned result without rendering (`ReviewModel.previewResult`).
     **Still open:** a true A/B toggle against the original, and including
     filler/retake cuts in the review (today it's pauses/structure cuts only).
2. **Keyboard-driven cut review** — in the review timeline: `J/K/L` to move between
   cuts, `space` to toggle keep/remove, and a **"play across this cut"** button to
   hear whether a join is clean. Pairs with the smooth-cuts work.
3. **Re-weight the progress bar** — fix the "rockets to ~60% then crawls": give the
   encode phase a bigger share so the bar tracks wall-clock. Small (stage labels
   already exist).

## ⚡ Speed (the cost is the re-encode, not the model)

4. **Smart-cut / stream-copy hybrid** — *the* speed lever. Copy the video stream
   losslessly for the interior of each kept segment and only re-encode the few frames
   at each cut boundary (GOP edges). Most of a video is copied, not encoded — often
   5–10× faster on long videos. **Big effort** (GOP analysis, mixing copied +
   re-encoded segments, muxing), highest speed payoff.
5. **Cache the analysis between re-cleans** — re-cleaning the same file with only
   encoder/quality changed re-extracts audio + re-detects every time. Cache that
   (keyed by file + detection params) so encoder tweaks are instant. Cheap, safe.

## 🛟 Stability (what will actually bite real users)

6. **Preflight checks** — before a long render: enough disk space for the output, a
   valid video+audio stream, a decodable codec. Fail fast with a clear message
   instead of dying mid-encode.
7. **Graceful odd-input handling** — no-audio videos, corrupt/partial files, exotic
   codecs → a clean error, never a crash or a half-written file.
   - **Partially shipped:** failures already raise human-readable `CleanError`s with
     per-file isolation (a bad file doesn't kill the batch) and originals are never
     touched. **Still open:** input-type-specific messaging (no-audio vs corrupt vs
     exotic codec), stream-level preflight (see #6), and cleaning up a partial output
     left beside the source on hard-cancel.

## 🔁 Cross-cutting (polish + the model flywheel)

8. **Review-timeline feedback loop** — capture which predicted cuts the user keeps vs
   removes → labeled data from real usage → feeds the next model. The "reward/treat"
   idea done right (active learning, not RL). Both a UX win (the app learns your
   taste) and the highest-leverage long-term data source. Already noted in
   `research/NOTES.md` §6 as "data collection — later".

## 🌍 Reach (more audience, same engine)

9. **Multi-language support** — the app is English-only today (whisper `en` model,
   `is_filler` vocab, retake matching tuned on English). Offer multilingual whisper
   models in the catalog and a language setting; pauses are already language-agnostic,
   so the work is fillers/captions/retakes + the model catalog. Biggest pure-reach
   expansion — opens Crisp to the global creator audience.
10. **Audio-first / podcast mode** — accept an audio file (or "export audio only"),
    run the same pauses + fillers + retakes pipeline, write a cleaned audio file. Same
    engine, a whole new use case (podcasters) — mostly skipping the video render path.

## 💎 Pro (justifies the paid tier)

11. **Chapter detection + export** — auto-generate YouTube / podcast chapter markers
    from long pauses + transcript topic shifts; export as chapter metadata or a
    timestamp list. Reuses the existing transcript; concrete, visible creator value.

## 🤝 Trust (build on what just shipped — retakes)

12. **"Why was this cut?" inspector** — the engine already logs a reason per cut
    (pause / filler / retake / long-run). Surface it in the review timeline with a
    one-click *keep this one*, so the engine's decisions become something the user
    understands and controls. Turns the retake/cut logic from a black box into trust;
    pairs with #1/#2 and feeds #8.
    - **Partially shipped:** a per-cut *keep* control exists (`ReviewModel.toggleCut`,
      tap-to-keep UI). **Still open:** carry the per-cut *reason* through to the UI
      (`CutRegion` has no reason field today) and include filler/retake cuts in the
      timeline.
13. **Pause "tighten" vs. "remove"** — option to *shorten* long pauses to a target
    (e.g. 0.3s) instead of cutting them entirely. Some creators find full removal too
    staccato; a tighten mode keeps natural rhythm. A new keep-segment strategy in
    `edit`, not a new detector.

---

## 🚀 Big swings — transcript-era & creator features

*Scoped to what the stack already makes cheap: whisper word-level timestamps, ffmpeg,
the frame-accurate cut engine, and native macOS Vision / AVFoundation. Ordered roughly
by coolness × leverage ÷ effort.*

### Flagship (paid-tier definers)

14. **Transcript-based editing (the Descript move).** Show the whisper transcript; the
    user deletes words/sentences *in text* and Crisp cuts those spans from the video.
    Turns Crisp from an auto-cleaner into an *editor* — the single biggest "wow." Word
    timestamps + the frame-accurate cut engine already exist; the new work is a
    transcript view ↔ timeline binding. **The killer paid feature.** Pairs with #1, #2,
    #12.
15. **Captions / subtitles export (`.srt` / `.vtt` + burned-in).** Nearly *free* —
    transcription already runs and the words are currently discarded. Add sidecar
    subtitle files plus an optional burned-in "open caption" style. Table-stakes creator
    value at almost zero engine cost. Pairs perfectly with #9 (multi-language).

### Reach (new audiences, same engine)

16. **Auto-reframe to vertical (Shorts / Reels / TikTok).** Use macOS **Vision** face
    detection to keep the speaker centered, then ffmpeg-crop to 9:16. One horizontal
    recording → a ready-to-post vertical. A reach bomb — opens the entire short-form
    creator market with a native, no-dependency face tracker.
17. **Speaker diarization** (whisper.cpp `tinydiarize`) — label who spoke when. Unlocks
    interviews/podcasts and makes audio-first mode (#10) genuinely useful.
18. **Highlight / clip extraction** — use long pauses + transcript topic shifts (the same
    signal as chapter detection #11) to auto-suggest 2–3 short clips from a long
    recording. A "give me the highlights" button.

### Premium polish (sounds / looks pro)

19. **"Studio sound" audio pass.** ffmpeg `afftdn` / `arnndn` denoise + `loudnorm` to
    **-14 LUFS** (YouTube's target) behind one toggle — audio that sounds mastered. Low
    effort, high perceived quality; on-brand with "honest about quality."
20. **Auto-zoom / punch-in to mask jump cuts.** A subtle scale/crossfade after each cut
    so joins don't feel jarring — mechanical jump-cuts start to look intentionally
    edited. Pairs with #2 ("play across this cut") and the smooth-cuts work.
21. **Speaking analytics / "filler report."** You already detect fillers, pauses, and
    retakes — surface a post-clean card: WPM, filler density ("you said 'um' 47×"),
    longest pause, talk time. Fun, shareable, and a coaching angle no one else in this
    niche has.

---

## Suggested sequence
1. **Captions / subtitles export** (#15 — almost free, ships fast)
2. **Result preview + keyboard review** (#1 / #2 — polish, low risk)
3. **Transcript-based editing** (#14 — the flagship)
4. **Multi-language** (#9 — biggest audience expansion)
5. **Smart-cut** (#4 — big project, highest speed payoff)
6. **Feedback loop** (#8 — the flywheel)
