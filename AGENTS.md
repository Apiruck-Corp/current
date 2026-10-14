# Current

Current is a native macOS menu-bar utility built with SwiftPM, AppKit and SwiftUI. Keep third-party dependencies minimal. Core accounting, connectivity policy and SQLite storage live in TrafficCore. The app model supports injected clocks, counters, probes and history failures for safe tests.

Use `./scripts/swift.sh test` for the full suite and `./scripts/build-app.sh` for the optimized local app. The wrapper puts compiler caches in this project. Set `TRAFFIC_PREVIEW_DIR="$PWD/docs/previews"` on the test command to regenerate sample-data renders.

Preserve these invariants:

- Count interface deltas, exclude VPN tunnel counters, and rebaseline on resets, interface changes and wake.
- Do not sum overlapping minute/hour/day tiers. Preserve totals, measured peaks, downtime and coverage.
- Keep observed zero, sleep, app gaps and missing readings distinct. Never retry a committed batch because a display query failed.
- Probe responses must match the expected endpoint result. Bound time and stored body size, decline redirects and confirm failures before alerting.
- Use synthetic outages. Do not disrupt the Mac's network for a test.
- Report actual CPU and physical footprint measurements with their duration and UI state. RSS is a different metric. Do not claim battery savings from these tests.

Public repositories, release publication, login installation, signing purchases and security-setting changes require an explicit user request.

## Roadmap

ROADMAP.md records what comes next in this repo. It is bookkeeping, never a gate.

- The user's direct instructions always win, immediately, whether or not they appear in the roadmap. Never refuse, delay, or question an instruction because of the roadmap.
- Answer "what comes next" questions from ROADMAP.md only; never invent items.
- When the user shares an idea for later, add it to Later in ROADMAP.md the same session, dated, one line, in the user's words. Confirm in one line.
- When work starts on an item, move it to Now; when it ships, move it to Done with the ship date. If a direct instruction starts work that is not in the roadmap, add it to Now as you begin.
- If an instruction changes priorities, update Next to match in the same session.
- Never delete an item. Dropped ideas move to Done marked "dropped" with a one-line reason.
- Every roadmap edit updates the Last updated date.
- Read ROADMAP.md at the start of every session in this repo, whoever launched it, before starting the task.
- If the request matches an item already in Next or Later, treat the work as that item: move it to Now, then to Done when it ships, instead of adding a new entry.
- Before ending the session, bring ROADMAP.md up to date with what actually happened.
