# cf_display — Initial Implementation Plan

A desk info display: Raspberry Pi (3B, possibly newer) + 720×720 screen, running a
Processing (Java) sketch straight from boot. Developed mainly on Windows PC and
MacBook in VS Code, pushed to GitHub, pulled and built on the Pi.

This plan covers the **skeleton** only: architecture, simulation, fake data,
placeholder screens, and Pi boot setup. No real APIs, no CRT shader yet.

> **Status (2026-09-26):** steps 0–7 and 9 done on desktop (Windows). **Step 8 (Pi)
> postponed** until the hardware is at hand — the detailed to-do list is in
> [CLAUDE.md](CLAUDE.md) under "Status and pending work". Mac run (step 0) not yet verified.

---

## 1. Decisions made

| Topic | Decision |
|---|---|
| Language | Processing 4 (latest) — a sketch with `.pde` + plain `.java` files |
| Build | Processing's built-in CLI (`Processing cli --run`) on every machine (PC, Mac, Pi). No Gradle. |
| Editor | VS Code |
| Renderer | `P2D` everywhere |
| Pi OS | Raspberry Pi OS **Lite 64-bit** + minimal X11 (`startx`), no desktop environment |
| Autostart | Auto-login on console → `startx` → run script → sketch |
| Repo | Repo root **is** the sketch folder (`cf_display/`). Whole repo cloned on the Pi; build happens on the Pi after `git pull` |
| Secrets | Never in git. Local, git-ignored config file per machine |
| Hardware | Behind an interface; **simulated** on desktop, real GPIO on Pi, switched by config |
| Data | Behind interfaces; **fake** sources in skeleton, real API sources added later |
| Screens | Fresh by default, optional kept state |
| Triggers | Queued, not immediate |
| Assets | Fonts (later images, shaders) preloaded in `setup()`, fonts from files in `data/` |

---

## 2. Architecture

### 2.1 The one rule

- **`.pde` files = everything visual.** Screens, transitions, drawing helpers, debug overlay.
  They are merged by Processing into one class, so they can call `rect()`, `text()` etc. directly.
- **`.java` files = everything non-visual.** Data, APIs, hardware, scheduling, timing, config.
  They never draw. They don't know about Processing drawing at all.

So: *if it draws, it's a `.pde`. If it thinks, it's a `.java`.*

Note on `.java` files: Processing does not preprocess them, so they must be plain Java
(e.g. `1.0f` for float literals, `public` classes, explicit imports).

### 2.2 Folder layout

Processing only compiles files at the **top level** of the sketch folder (no code
subfolders), so grouping is done with **file name prefixes**.

The repo root is the sketch folder itself. Processing requires the main file to
match the folder name, and sketch names can't contain `-`, so the folder is
`cf_display` and the main file `cf_display.pde`. Processing ignores the non-code
files and folders (docs, `scripts/`, `.vscode/`) that sit alongside the code.

```
cf_display/                      ← repo root = Processing sketch
├── PLAN.md
├── README.md
├── CLAUDE.md                    ← conventions for future Claude sessions (step 9)
├── .gitignore
├── .vscode/
│   └── tasks.json               ← "Run sketch" task for Windows + macOS
├── scripts/
│   ├── run-pi.sh                ← launched by X on the Pi
│   └── pi-setup.md              ← step-by-step Pi install notes
│
├── cf_display.pde               ← main: settings/setup/draw, wiring, key forwarding
│
├── screen_clock.pde             ← placeholder screen
├── screen_weather.pde           ← placeholder screen (uses fake weather data)
├── screen_calendar.pde          ← placeholder screen (uses fake calendar data)
├── screen_example.pde           ← learning example: phases, timeline, eases
├── transition_basic.pde         ← placeholder between-screen animation
├── ui_helpers.pde               ← shared drawing helpers (text styles, etc.)
├── ui_assets.pde                ← fonts etc., all loaded once at startup
├── debug_overlay.pde            ← debug view
│
├── CoreScreen.java              ← abstract base class for all screens (lifecycle)
├── CoreTransition.java          ← abstract base class for between-screen animations
├── CoreScheduler.java           ← decides what's on screen: queue, fallback cycle
├── CoreTimeline.java            ← timing toolkit
├── CoreEase.java                ← easing functions
├── CoreConfig.java              ← loads local config
├── CoreTriggers.java            ← rules for when data queues a screen
│
├── HwAction.java                ← enum of input actions (SKIP, SHOW_SCREEN, DEBUG, ...)
├── HwDevice.java                ← interface: actions in, LEDs out, sensor values
├── HwSimulated.java             ← keyboard/mouse → actions, fake sensors, LED state
├── HwPi.java                    ← real GPIO (stub in skeleton)
│
├── DataStore.java               ← holds latest data from all sources, thread-safe
├── DataSource.java              ← base for background-updating sources
├── DataWeather.java             ← weather data model
├── DataWeatherFake.java         ← fake weather source
├── DataCalendar.java            ← calendar data model
├── DataCalendarFake.java        ← fake calendar source
├── DataCalendarIcs.java         ← real calendar: published ICS links (Outlook, Google)
│
├── code/                        ← library jars: ical4j + its dependencies
│
└── data/
    ├── config.example.json      ← committed template
    ├── ProcessingSansPro-*.ttf  ← font (+ its license file)
    └── config.json              ← git-ignored, per machine
```

Prefixes: `Core*` (engine), `Hw*` (hardware), `Data*` (data) for `.java`;
`screen_*`, `transition_*`, `ui_*`, `debug_*` for `.pde`.
Adding a screen = add one `screen_*.pde` file + one line registering it in `cf_display.pde`.

### 2.3 Screens

Each screen is a class in its own `screen_*.pde` file extending `CoreScreen`.
Because it lives in a `.pde`, it can draw directly.

Lifecycle, managed by the scheduler:

```
INTRO → MAIN → OUTRO → DONE
```

- A screen gets its own `CoreTimeline` that resets at each phase change.
- The screen decides when each phase ends (e.g. intro finishes after its animation,
  main lasts N seconds or until data says so, outro finishes after its animation),
  and calls something like `nextPhase()`.
- The scheduler can *ask* a screen to wrap up (`requestOutro()`, e.g. on SKIP), but
  the screen plays its own outro — no hard cuts unless the screen chooses that.
- Methods a screen implements (roughly): `start()`, `drawIntro()`, `drawMain()`,
  `drawOutro()`, plus optional `onAction(HwAction)`.
- **Fresh by default:** the scheduler creates a new instance each time a screen is
  shown. A screen can opt in to **kept state** so the same instance is reused.
- A screen reads data from `DataStore`; it never fetches anything itself.

### 2.4 Timing toolkit (`CoreTimeline`, `CoreEase`)

Building blocks, not effects. All in seconds (float). Time comes from the sketch
(`millis()`), so `.java` stays independent of drawing.

- `t()` — seconds since this timeline started
- `progress(start, duration)` — 0..1 clamped, for "animate from 0.5 s for 1.2 s"
- `once(atSeconds)` — true exactly once when time passes that mark (fire events)
- `between(a, b)` — is time inside a window
- `CoreEase.inOutCubic(x)` etc. — a small set of easing functions

### 2.5 Scheduler and queue (`CoreScheduler`)

- Holds a registry of screens: an id (e.g. `"weather"`) → how to create it.
- Holds a **queue** of requests: `request(screenId, priority)`. Triggers (data sources,
  buttons, timers) only ever add to the queue.
- When the current screen reaches `DONE`:
  1. play the between-screen transition, if one is set (optional slot, `CoreTransition`)
  2. pick the next screen: highest-priority queued request, otherwise the **fallback
     rule** (skeleton: cycle through registered screens; random later)
- Thread-safe queue, because data sources run on background threads.
- The rules will grow later (time-of-day, cooldowns, "don't show twice in a row"…)
  without touching any screen code.

### 2.6 Hardware and simulation (`Hw*`)

- Code reacts to **actions**, never raw buttons: `SKIP`, `SHOW_SCREEN`, `TOGGLE_DEBUG`, …
  (exact set decided later; skeleton has a few).
- `HwDevice` interface: poll for actions, set LED states, read sensor values
  (light level, encoder position).
- `HwSimulated` (desktop): keys → actions (e.g. `→` = SKIP, `1–9` = show screen N,
  `D` = debug), keys/mouse adjust fake light level and encoder; LED states are
  shown in the debug overlay.
- `HwPi` (device): real GPIO. **Stub in the skeleton** — the GPIO library choice
  (Pi4J / processing.io / other) is decided later.
- Chosen at startup from config: `"hardware": "simulated"` or `"pi"`.
  No commenting code in and out.

### 2.7 Data layer (`Data*`)

- Each source runs on a **background thread** and updates on its own interval, so
  API calls never stall animation.
- Results go into `DataStore` as simple data objects (`DataWeather`, `DataCalendar`),
  plus a status per source (ok / error / last updated) for the debug view.
- **Triggers** live in `CoreTriggers`, not in the sources: sources only fetch, triggers
  only decide (e.g. "event in 5 min" → `request("calendar", HIGH)`). A rule keeps
  working when a fake source is swapped for a real one.
- Skeleton: only `*Fake` sources, generating plausible changing data.
  Real sources (`DataWeatherOpenMeteo`, `DataCalendarIcs`, Slack, Harvest…)
  are added later as new files next to the fakes; config picks which one runs.
- Calendar (decided 2026-09-28): published **ICS links** instead of Microsoft Graph.
  Both Microsoft accounts allow "Publish a calendar" with full details, so no app
  registration, admin consent or sign-in on the Pi is needed. Google uses its secret
  iCal address the same way. `sources.calendar: "ics"` reads the `calendars` list in
  config and merges all feeds into one `DataCalendar`. Parsing uses the ical4j
  library (jars in `code/`), because recurring meetings (exceptions, moved single
  occurrences, Windows time zone names in Outlook feeds) are too easy to get wrong by hand.

### 2.8 Config (`CoreConfig`)

`data/config.json` — git-ignored, one per machine, copied from
`config.example.json`. Skeleton keys (roughly):

```json
{
  "hardware": "simulated",
  "fullscreen": false,
  "debug": true,
  "sources": { "weather": "fake", "calendar": "fake" }
}
```

Later: API keys/tokens live here too (never committed).

### 2.9 Debug view

Toggled by the `TOGGLE_DEBUG` action. Drawn last, on top of everything. Shows:
fps and draw time, current screen + phase + time in phase, queue contents,
hardware state (simulated LEDs, light level, encoder), data source statuses.

### 2.10 Future CRT shader — leave room, don't build

Screens draw straight to the main canvas. A post-processing shader can later be
applied at the end of `draw()` (e.g. `filter(crtShader)`) without changing screens.

### 2.11 Assets (`ui_assets.pde`)

Anything loaded on first use freezes the sketch for a moment, and because the timeline
runs on real time, a freeze during an animation makes it skip (on the Mac the first
font lookup by name took 2+ s). So `setup()` starts the data sources, then
`loadAssets()` loads every font (one per size, from files in `data/`) before the
scheduler starts the first screen.

---

## 3. Running

### Desktop (PC / Mac)

- VS Code task **"Run sketch"** calls `Processing cli --sketch=<repo> --run`.
  Since Processing 4.5 the CLI is built into the main executable (no separate
  `processing-java`). Verified with 4.5.6 on Windows.
  - Windows: `C:\Program Files\Processing\Processing.exe cli ...`
  - macOS: `/Applications/Processing.app/Contents/MacOS/Processing cli ...` (to verify on the Mac)
- Window 720×720, simulated hardware, fake data.

### Pi

- Processing 4 (Linux ARM 64-bit build) installed on the Pi.
- Boot: console auto-login → `~/.bash_profile` runs `startx` on tty1 → `~/.xinitrc`
  runs `scripts/run-pi.sh` → `Processing cli --sketch=... --run` (exact Linux path verified in step 8).
- `run-pi.sh` also: disables screen blanking (`xset s off -dpms`), hides cursor.
- Update flow over SSH: `git pull` then restart the sketch (script or reboot).
- P2D needs the KMS GL driver (`dtoverlay=vc4-kms-v3d`, default on current Pi OS).
- Display-specific config (HDMI vs DSI, 720×720 timings) → **TBD when display is checked.**

---

## 4. Build steps

Each step ends in something runnable. Work on desktop first; Pi at step 8.

**Step 0 — Repo and tooling**
- `git init`, `.gitignore` (config.json, export folders, OS junk), README stub.
- Empty `cf_display.pde` in the repo root (720×720 P2D, background colour).
- VS Code task for Windows + macOS.
- ✅ Done when: the empty sketch runs from VS Code on the PC and the Mac.

**Step 1 — Config**
- `CoreConfig`, `config.example.json`, fullscreen/windowed from config.
- ✅ Done when: changing `config.json` changes behaviour without code edits; missing
  file gives a clear message.

**Step 2 — Timing toolkit**
- `CoreTimeline`, `CoreEase`.
- ✅ Done when: a test animation in main draws a shape moving with easing, and an
  event fires exactly once at a set time.

**Step 3 — Screens**
- `CoreScreen` with lifecycle; `screen_clock.pde` with a real intro/main/outro animation.
- ✅ Done when: the clock screen plays intro → main → outro and reports DONE.

**Step 4 — Scheduler**
- `CoreScheduler` with registry, queue, fallback cycle, fresh/kept state.
- `CoreTransition` + `transition_basic.pde`.
- Add `screen_weather.pde`, `screen_calendar.pde` (placeholders).
- ✅ Done when: screens cycle forever with transitions between them.

**Step 5 — Input and simulated hardware**
- `HwAction`, `HwDevice`, `HwSimulated`, `HwPi` stub, key forwarding from main.
- ✅ Done when: SKIP makes the current screen play its outro early; number keys queue
  a specific screen; config switches to `pi` mode without crashing on desktop
  (stub just logs).

**Step 6 — Data layer**
- `DataStore`, `DataSource`, weather + calendar models and fake sources.
- Placeholder screens show fake data; fake calendar posts a queued trigger.
- ✅ Done when: data changes over time on screen, and a fake "upcoming event" makes
  the calendar screen come up next.

**Step 7 — Debug view**
- `debug_overlay.pde` with the info listed in 2.9.
- ✅ Done when: toggling shows fps, screen/phase, queue, hardware and source status.

**Step 8 — Pi** ⏸ *postponed — see pending list in CLAUDE.md*
- Write `scripts/pi-setup.md` and `scripts/run-pi.sh`; set up the Pi from a fresh
  Pi OS Lite 64-bit image.
- ✅ Done when: Pi boots straight into the sketch fullscreen, `git pull` + restart
  updates it, and fps with the placeholder screens is measured and noted.

**Step 9 — Docs**
- `README.md` (what it is, how to run on each machine), `CLAUDE.md` (architecture
  rules, naming conventions, "if it draws it's a .pde").
- ✅ Done when: someone (or a new Claude session) can add a screen by following the docs.

---

## 5. Open questions (not blocking the skeleton)

- **Display:** HDMI or DSI? Affects Pi config in step 8.
- ~~**Calendar:** Graph or ICS?~~ Decided: ICS links (see 2.7). Client accounts
  that don't allow publishing would need their own solution (Graph, or busy-only ICS).
- **GPIO library** for `HwPi`.
- **Analog light sensors:** ADC or I²C sensor (user will decide).
- **Sleep mode** behaviour and whether the display backlight can be controlled.
- **CRT shader** design and its performance on the Pi 3B.
- **Pi model:** 3B unless performance forces an upgrade.
- **Scheduler rules** beyond simple cycling.
- **Button → action mapping.**
