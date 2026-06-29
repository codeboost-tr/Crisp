# Crisp — roadmap

The roadmap now lives in **GitHub Issues + a Project board**, not in this file.
Track work there instead of hand-editing markdown.

## Where to look

- **Board (what to do next):** https://github.com/users/rafay99-epic/projects/4
  — grouped by **Priority**: `Now` → `Next` → `Backlog`.
- **Issues:** https://github.com/rafay99-epic/Crisp/issues

## Conventions

- **Priority labels:** `priority:now` (committed foundations), `priority:next`
  (committed feature wave), `priority:backlog` (longer horizon).
- **Area labels:** `area:licensing`, `area:platform`, `area:audio`, `area:video`,
  `area:transcript`, `area:engine`, `area:ux`, `area:ml`, `area:reach`.
- A PR that closes an item references it (`Closes #NN`) so the board auto-updates.

## Committed order (snapshot)

Foundations first, then the feature wave:

1. Licensing & paid tier via Polar.sh — #85
2. Windows support (shared core + native UI) — #87
3. Captions / subtitles export — #88
4. Auto-reframe to vertical / short-form — #89
5. "Studio sound" audio pass — #90
6. Speaker diarization — #91
7. Cut / chapter markers during the cut — #92
8. Audio volume / gain control — #93

Quick views:

```sh
gh issue list --label priority:now      # the foundations
gh issue list --label priority:next     # the feature wave
```

> Shipped & pruned so far: VFR handling (PR #77), Export to editor / FCPXML
> (PR #79), Quit guard during render (PR #80). See git history for the record.
