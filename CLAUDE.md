# CLAUDE.md

Guidance for Claude Code sessions working in this repo.

## Project

cf_display is a desk info display: Raspberry Pi (3B, maybe newer later) + 720×720 screen,
running a Processing 4 (Java) sketch that starts on boot. The owner is a hobbyist coder:
code stays easy to read ([CODING_STANDARDS.md](CODING_STANDARDS.md)).

Developed on Windows and macOS in VS Code; code goes via GitHub to the Pi, which
builds and runs it itself. See [PLAN.md](PLAN.md) for the full plan and history of decisions.

## Topic docs

Read the matching doc before working on:

- **Calendar** (`DataCalendar*`, `screen_calendar.pde`, ICS feeds, the timeline): [docs/calendar.md](docs/calendar.md)
- **Character blocks** (`char_block.pde`, any Block-based screen, the char font): [docs/char-blocks.md](docs/char-blocks.md)
- **Video** (`CoreVideo`, `data/video/`, frame export): [docs/video.md](docs/video.md)
- **Raspberry Pi** (setup, deployment, performance to measure): [docs/pi.md](docs/pi.md)

## Build and run

Processing 4.5+ has its CLI built into the main executable (no `processing-java`):

- Windows: `& "C:\Program Files\Processing\Processing.exe" cli --sketch="<repo>" --run`
- macOS: `/Applications/Processing.app/Contents/MacOS/Processing cli --sketch="<repo>" --run`
- Compile only (fast check, no window): replace `--run` with `--build`
- VS Code: default build task "Run sketch" (`Ctrl/Cmd+Shift+B`)
- `scripts/check.sh`: rule checks + build, ~2 s. Also the pre-commit hook, enabled once
  per clone with `git config core.hooksPath scripts/hooks`.

Harmless console noise: `display count needs to be implemented for non-AWT`,
`AWT disabled, displayWidth/displayHeight will be 0`, `Could not set writable for all`.

VS Code's Java diagnostics show false errors for this sketch (it doesn't understand how
Processing merges `.pde` files). Trust the Processing build, not the red squiggles.

When verifying changes: build, then run for a while and read the console log
(every component logs with a `[tag]` prefix). For visual checks, set `config.json`
`"capture": [300, 500]`: those frames land in `capture/` and the sketch quits by itself
(set it back to `[]` after). Runs in the foreground, so each one ends on its own.
`"fakeTime": "08:45"` picks the time of day to look at.

## Architecture rules

**If it draws, it's a `.pde`. If it thinks, it's a `.java`.**

- `.pde` files: screens, transitions, drawing helpers, debug overlay. Processing merges
  them into one class, so they call `rect()`, `text()` etc. directly.
- `.java` files: data, APIs, hardware, scheduling, timing, config. They never draw.
  They are plain Java (not preprocessed): `1.0f` float literals, explicit imports, `public`.
- The repo root is the sketch folder. Processing only compiles top-level files, so there
  are **no code subfolders** — grouping is by file name prefix. The one exception is
  `code/`: Processing's folder for library jars (ical4j + its dependencies). When adding
  a jar, add its dependencies too (check the library's Maven `pom`) and say why in the docs.

| Prefix | Kind | Examples |
|---|---|---|
| `Core*.java` | engine | `CoreScreen`, `CoreScheduler`, `CoreTimeline`, `CoreEase`, `CoreClock`, `CoreConfig`, `CoreTriggers`, `CoreTransition`, `CoreVideo` |
| `Hw*.java` | hardware | `HwAction`, `HwDevice`, `HwSimulated`, `HwPi` |
| `Data*.java` | data | `DataStore`, `DataSource`, `DataWeather`, `DataWeatherFake`, `DataCalendarIcs` |
| `screen_*.pde` | one screen per file | `screen_clock.pde` → `class ScreenClock` |
| `transition_*.pde` | between-screen animations | `transition_basic.pde` |
| `ui_*.pde` | shared drawing/formatting helpers, assets | `ui_helpers.pde`, `ui_assets.pde` |
| `char_*.pde` | character blocks | `char_block.pde` |
| `debug_*.pde` | debug view, capture mode | `debug_overlay.pde`, `debug_capture.pde` |

`cf_display.pde` is only wiring: settings/setup/draw, registering screens, creating
sources and hardware, routing input. Keep logic out of it.

### How things flow

```
HwDevice ──actions──▶ cf_display.handleActions() ──▶ scheduler.skip()/request() or screen.onAction()
DataSource (background thread) ──▶ DataStore ◀── screens read while drawing
CoreTriggers (reads DataStore) ──request()──▶ CoreScheduler queue
CoreScheduler ──▶ current screen: INTRO → MAIN → OUTRO → DONE ──▶ transition ──▶ next screen
```

### Screens

- Extend `CoreScreen`, implement `drawIntro()`, `drawMain()`, `drawOutro()`; call
  `nextPhase()` when a phase is finished. Optional: `start()`, `onAction()`, `keepsState()`.
- Methods are written **without `public`** (the base class declares them package-private
  on purpose, so `.pde` code looks like normal Processing).
- `tl` is a `CoreTimeline` restarting at 0 each phase: `tl.t()`, `tl.progress(start, dur)`,
  `tl.once(at)`, `tl.between(a, b)`, `tl.every(interval)`. Combine with `CoreEase.*`
  (`CoreEase.cubicBezier(x1, y1, x2, y2, x)` takes numbers from cubic-bezier.com).
- Screens are fresh instances each time unless `keepsState()` returns true.
- Screens read data from `store` (can be null before first fetch — always handle it)
  and never fetch anything themselves. Snapshot lists in `start()` if rows must not
  change mid-animation.
- Register in `cf_display.pde`: `scheduler.register("id", () -> new ScreenX());`
  Registration order = fallback cycle order = number keys in simulation.

### Scheduler and triggers

- Requests are **queued, never interrupting**. `request(id, priority)` is thread-safe.
- Trigger rules ("event in 5 min → show calendar") go in `CoreTriggers`, not in data
  sources. Sources only fetch; triggers only decide.

### Data

- New API = new `Data<Thing><Provider>.java` extending `DataSource`, next to the fake
  one, selected in `createXSource()` in `cf_display.pde` from `config.json` `sources.*`.
- `fetch()` runs on a background thread; put an immutable result in `DataStore`.
  Throwing is fine — the error is recorded and old data kept.
- Never do network or file I/O on the draw thread.

### Hardware

- Code reacts to `HwAction`s, never to raw keys/pins. Add new actions to `HwAction`.
- `HwSimulated` (desktop, keyboard/mouse) and `HwPi` (GPIO) chosen by `"hardware"` in config.

## Conventions

- Time: seconds as `float`, from `now()` in `cf_display.pde` (the only clock read).
  Date and time of day: `CoreClock.now()` / `CoreClock.today()`, so config `"fakeTime"`
  (pretend it's that time of day; `""` = real time) reaches every screen and source.
- Frame rate: `FRAME_RATE` in `cf_display.pde` is the only place to change it (the video
  timing and the debug graph follow it). Keep the display's refresh rate the same, e.g.
  50 fps on a 60 Hz screen can't be even.
- Assets: fonts (later images, shaders) are loaded once in `loadAssets()` in `ui_assets.pde`,
  never on first use inside a screen (a first font lookup by name froze the Mac for 2+ s).
  Font files live in `data/` (Iosevka in `data/fonts/`).
- Naming trap: a method in a `.pde` class hides every sketch function with the same name
  inside that class (a `CharBlock.fill()` would break `fill(color)` in its `draw()`).
  Name methods differently from the Processing functions the class calls.
- P2D gotchas: an `arc()` with zero size or zero sweep prints a tessellation error — skip it.
  A stroked rounded `rect()` gets a spike where the outline closes unless `strokeJoin(ROUND)`.
- Secrets and per-machine settings: `data/config.json` (git-ignored). Template with
  every key: `data/config.example.json` — keep it updated when adding keys.
- Git: LF line endings (`.gitattributes`). Never commit or push on your own: only when
  the owner asks. One commit per finished step.

## Status

Steps 0–7 and 9 of PLAN.md are done; step 8 (Raspberry Pi) is not ([docs/pi.md](docs/pi.md)).
Other open items: verify the Mac run (step 0), sleep mode, CRT shader design, scheduler
rules beyond cycling, button → action mapping, the calendar fetch failure warning
([docs/calendar.md](docs/calendar.md)).

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `valtterimaki/cf_display` (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the repo root; ADRs go in `docs/adr/` (created with the first one). See `docs/agents/domain.md`.
