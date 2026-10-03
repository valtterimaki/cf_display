# CLAUDE.md

Guidance for Claude Code sessions working in this repo.

## Project

cf_display is a desk info display: Raspberry Pi (3B, maybe newer later) + 720×720 screen,
running a Processing 4 (Java) sketch that starts on boot. The owner is a hobbyist
coder: keep code **clean and professional but easy to read**. Clear names, short
comments explaining *why*, no clever tricks, no unnecessary abstraction.

Developed on Windows and macOS in VS Code; code goes via GitHub to the Pi, which
builds and runs it itself. See [PLAN.md](PLAN.md) for the full plan and history of decisions.

## Build and run

Processing 4.5+ has its CLI built into the main executable (no `processing-java`):

- Windows: `& "C:\Program Files\Processing\Processing.exe" cli --sketch="<repo>" --run`
- macOS: `/Applications/Processing.app/Contents/MacOS/Processing cli --sketch="<repo>" --run`
- Compile only (fast check, no window): replace `--run` with `--build`
- VS Code: default build task "Run sketch" (`Ctrl/Cmd+Shift+B`)

Harmless console noise: `display count needs to be implemented for non-AWT`,
`AWT disabled, displayWidth/displayHeight will be 0`, `Could not set writable for all`.

VS Code's Java diagnostics show false errors for this sketch (it doesn't understand how
Processing merges `.pde` files). Trust the Processing build, not the red squiggles.

When verifying changes: build, then run for a while and read the console log
(every component logs with a `[tag]` prefix). For visual checks, temporarily add
`saveFrame("<scratchpad>/shot_####.png")` at a given `frameCount` — and remove it after.

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
| `Core*.java` | engine | `CoreScreen`, `CoreScheduler`, `CoreTimeline`, `CoreEase`, `CoreConfig`, `CoreTriggers`, `CoreTransition`, `CoreVideo` |
| `Hw*.java` | hardware | `HwAction`, `HwDevice`, `HwSimulated`, `HwPi` |
| `Data*.java` | data | `DataStore`, `DataSource`, `DataWeather`, `DataWeatherFake`, `DataCalendarIcs` |
| `screen_*.pde` | one screen per file | `screen_clock.pde` → `class ScreenClock` |
| `transition_*.pde` | between-screen animations | `transition_basic.pde` |
| `ui_*.pde` | shared drawing/formatting helpers, assets | `ui_helpers.pde`, `ui_assets.pde` |
| `debug_*.pde` | debug view | `debug_overlay.pde` |

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
  `tl.once(at)`, `tl.between(a, b)`, `tl.every(interval)`. Combine with `CoreEase.*`.
- Screens are fresh instances each time unless `keepsState()` returns true.
- Screens read data from `store` (can be null before first fetch — always handle it)
  and never fetch anything themselves. Snapshot lists in `start()` if rows must not
  change mid-animation.
- Register in `cf_display.pde`: `scheduler.register("id", () -> new ScreenX());`
  Registration order = fallback cycle order = number keys in simulation.
- Animations are hand-crafted per screen. Don't build generic effect systems — only
  timing building blocks.

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
- Calendar: `DataCalendarIcs` reads every link in `config.json` `calendars` (Outlook
  published ICS, Google secret iCal address), expands recurring events with ical4j,
  converts times to the machine's local time, and merges the feeds (same title + start
  = one event). A failing feed keeps its last events. Never log or display a feed URL —
  it's a secret. To test without real links, parse a local `.ics` file with the static
  `DataCalendarIcs.parseEvents()`, or serve test files with `python3 -m http.server`.

### Video

- Videos are frame sequences in `data/video/<name>/`, files named
  `<name>_<5-digit frame number>` (`rooster_00000.png`, from After Effects) —
  `.jpg` for footage, `.png` for transparency or flat graphics. Played by `CoreVideo`,
  not the Processing video library (GStreamer): it was unreliable on the Pi in an
  earlier project.
- Load in `loadAssets()` with `loadVideo(name, fps, loop)`; screens draw
  `image(video.frame(seconds), x, y, w, h)` — any size, tint or shader.
- A background thread decodes a few frames ahead into reused arrays. Debug view shows
  per video: average decode time vs. budget (1000 / fps ms) and late frames.
- Frame export: `ffmpeg -i in.mov -vf scale=720:720 -q:v 3 data/video/<name>/<name>_%05d.jpg`
  (PNG with alpha: `-pix_fmt rgba .../<name>_%05d.png`).

### Hardware

- Code reacts to `HwAction`s, never to raw keys/pins. Add new actions to `HwAction`.
- `HwSimulated` (desktop, keyboard/mouse) and `HwPi` (GPIO) chosen by `"hardware"` in
  config. Never comment code in/out for desktop vs Pi — use the config switch.

## Conventions

- Time: seconds as `float`, from `now()` in `cf_display.pde` (the only clock read).
- Frame rate: `FRAME_RATE` in `cf_display.pde` is the only place to change it (the video
  timing and the debug graph follow it). Keep the display's refresh rate the same, e.g.
  50 fps on a 60 Hz screen can't be even. A video's own fps (`loadVideo`) is its render rate.
- Assets: fonts (later images, shaders) are loaded once in `loadAssets()` in `ui_assets.pde`,
  never on first use inside a screen (a first font lookup by name froze the Mac for 2+ s).
  One `PFont` per size; screens call `textFont(fontBody)` etc., not `textSize()`.
  Font files live in `data/`.
- Displayed numbers/times: use `ui_helpers.pde` (`fmtDecimal`, `fmtTemperature`,
  `fmtTime`, `fmtTimeUntil`) — locale-independent, so PC (Finnish locale), Mac and Pi match.
- Anything drawn on top of screens: wrap in `pushStyle()`/`popStyle()`.
- P2D gotcha: an `arc()` with zero size or zero sweep prints a tessellation error — skip it.
- Logging: `System.out.println("[tag] message")` with tags like `[screen]`, `[scheduler]`,
  `[data]`, `[trigger]`, `[hw]`, `[input]`, `[config]`, `[assets]`.
- Secrets and per-machine settings: `data/config.json` (git-ignored). Template with
  every key: `data/config.example.json` — keep it updated when adding keys.
- Git: LF line endings (`.gitattributes`). One commit per finished step. Push only
  when the owner asks.

## Status and pending work

Steps 0–7 and 9 of PLAN.md are done. **Step 8 (Raspberry Pi) is not done yet** —
the Pi has no OS installed. Still needed for the Pi:

- [ ] Check which display interface the 720×720 screen uses (HDMI or DSI) and its config (timings, rotation)
- [ ] Install Raspberry Pi OS Lite 64-bit, minimal X11 (`xserver-xorg`, `xinit`), git
- [ ] Install Processing 4.5.x Linux ARM 64-bit; verify the CLI path/command on Linux
- [ ] Check the KMS GL driver (`dtoverlay=vc4-kms-v3d`) and that P2D runs on the 3B
- [ ] Write `scripts/pi-setup.md` (step-by-step install notes) and `scripts/run-pi.sh`
- [ ] Autostart: console auto-login → `~/.bash_profile` runs `startx` on tty1 → `~/.xinitrc` runs `scripts/run-pi.sh`
- [ ] `run-pi.sh`: disable screen blanking (`xset s off -dpms`), hide the mouse cursor, maybe restart the sketch if it crashes
- [ ] Update flow over SSH: `git pull` + restart sketch (script or reboot)
- [ ] Pi `data/config.json`: `"hardware": "pi"`, `"fullscreen": true`, `"debug": false`, calendar links
- [ ] Set the Pi's time zone (`raspi-config` → Localisation): calendar times are shown in the machine's local time
- [ ] Check how long the first calendar parse takes on the 3B (about 0.6 s on the Mac)
- [ ] Run the display at the same refresh rate as `FRAME_RATE`, otherwise motion is uneven
- [ ] Measure video decode time on the 3B (debug view; ~10 ms per 720×720 frame on the Mac, budget 33 ms at 30 fps). Too slow → smaller frames drawn scaled up, or more decode threads
- [ ] Measure FPS with the debug view; later test the CRT shader's performance on the 3B
- [ ] Choose GPIO library (Pi4J / processing.io / other) and implement `HwPi` (buttons, encoder, LEDs, light sensor via ADC or I²C)

Other open items: verify the Mac run (step 0), sleep mode, CRT shader design, scheduler
rules beyond cycling, button → action mapping.

Calendar access is decided: published ICS links (`DataCalendarIcs`). Microsoft Graph is
only needed if a future account doesn't allow publishing; it would be another
`DataCalendar<Provider>` source.
