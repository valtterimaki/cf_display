# cf_display

A desk info display: a Raspberry Pi with a 720×720 screen, running a Processing 4
sketch that cycles through animated screens (clock, weather, calendar, …) and
brings up relevant ones when something happens — like a meeting about to start.

Everything can be developed and tested on a normal computer: hardware (buttons,
knob, LEDs, light sensor) is simulated with the keyboard and mouse, and data
comes from fake sources until real APIs are connected.

## Requirements

- [Processing](https://processing.org/download) 4.5 or newer
- VS Code (optional, but the run task is set up for it)

## Running on desktop

1. Copy `data/config.example.json` to `data/config.json` (it's git-ignored; each
   machine has its own). If you skip this, the example file is used.
2. In VS Code: **Ctrl+Shift+B** (Windows) / **Cmd+Shift+B** (Mac) runs the sketch.

From a terminal:

- Windows: `& "C:\Program Files\Processing\Processing.exe" cli --sketch="<repo path>" --run`
- macOS: `/Applications/Processing.app/Contents/MacOS/Processing cli --sketch="<repo path>" --run`

Use `--build` instead of `--run` to only check that it compiles.

## Keys (simulated hardware)

| Key | Action |
|---|---|
| Space / → | Skip — current screen plays its outro early |
| 1 – 9 | Queue a screen (1 = clock, 2 = weather, 3 = calendar) |
| D | Debug view on/off |
| `,` / `.` or mouse wheel | Turn the knob |
| Enter | Press the knob |
| `-` / `+` | Simulated light level down / up |
| Esc | Quit |

## Config (`data/config.json`)

| Key | Values | Meaning |
|---|---|---|
| `hardware` | `"simulated"` / `"pi"` | Keyboard/mouse stand-in, or real GPIO |
| `fullscreen` | `true` / `false` | Fullscreen, or a 720×720 window |
| `debug` | `true` / `false` | Debug view visible at startup |
| `sources.weather` | `"fake"` | Where weather data comes from |
| `sources.calendar` | `"fake"` / `"ics"` | Where calendar data comes from. `"ics"` reads the `calendars` links |
| `calendars` | list of `{ "name": …, "url": … }` | Published calendar links, merged into one calendar. `name` is shown on screen |

API keys and tokens will go here too — never commit this file.

### Calendar links

Each calendar has a secret ICS link. Anyone who has the link can read that
calendar, so it only goes in `config.json`.

- **Outlook / Microsoft 365:** Outlook on the web → Settings → Calendar → Shared
  calendars → *Publish a calendar* → pick the calendar and "Can view all details" →
  Publish → copy the **ICS** link (not the HTML one).
- **Google:** Google Calendar settings → the calendar → *Integrate calendar* →
  **Secret address in iCal format**.

The display shows events in the computer's own time zone, so set that correctly
(on the Pi too).

## How the code is organised

**If it draws, it's a `.pde`. If it thinks, it's a `.java`.**

All files sit in the repo root (Processing doesn't compile code in subfolders),
grouped by name:

- `cf_display.pde` — main file; only wires everything together
- `screen_*.pde` — one screen per file
- `transition_*.pde` — animations between screens
- `ui_*.pde`, `debug_*.pde` — shared drawing helpers, debug view
- `Core*.java` — engine: screen lifecycle, scheduler, timing, easing, config, triggers
- `Hw*.java` — hardware: actions, simulated and Pi implementations
- `Data*.java` — data: store, sources, data models
- `code/` — library jars (Processing's folder for them): ical4j for calendar feeds, plus what it needs

Each screen goes through **intro → main → outro**, and decides itself when each
phase ends. A scheduler picks what to show next: queued requests first (from
buttons or triggers like an upcoming meeting), otherwise it cycles through screens.

### Adding a screen

1. Create `screen_something.pde`:

   ```java
   class ScreenSomething extends CoreScreen {
     void drawIntro() { background(0); /* ... */ if (tl.t() > 1.0) nextPhase(); }
     void drawMain()  { background(0); /* ... */ if (tl.t() > 8.0) nextPhase(); }
     void drawOutro() { background(0); /* ... */ if (tl.t() > 0.8) nextPhase(); }
   }
   ```

   `tl` is a timeline that restarts at 0 in each phase. Handy with easing:
   `float x = lerp(0, 500, CoreEase.outCubic(tl.progress(0.2, 1.0)));`

2. Register it in `setup()` in `cf_display.pde`:

   ```java
   scheduler.register("something", () -> new ScreenSomething());
   ```

## Raspberry Pi

Not set up yet. See the pending list in [CLAUDE.md](CLAUDE.md) and step 8 in [PLAN.md](PLAN.md).
