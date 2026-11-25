---
name: look
description: Screenshot the running sketch to check a visual change. Use after changing anything a screen draws or animates, when comparing against a Figma design, or when the owner reports something that looks wrong (wobble, gap, wrong timing).
---

Capture mode (`debug_capture.pde`) saves chosen frames to `capture/` and quits by itself. Each look is a temporary setup that must be fully restored afterwards.

## 1. Back up

```bash
S=<scratchpad>
cp data/config.json $S/config.bak && cp cf_display.pde $S/cf_display.bak
```

## 2. Set the scene

In `data/config.json`:

- `"capture": [frames]`. Frame = seconds × `FRAME_RATE` (50, in `cf_display.pde`), counted from sketch start. For an animation, pick frames across it: start, middle, end, and one after it has settled.
- `"fakeTime": "HH:MM"`, a time of day that shows the state you're checking (events in the morning, a bus after 14:00, etc.).
- `"debug": false`, unless the debug overlay is what you're checking.

In `cf_display.pde`, temporary edits only, so the target is on screen at those frames:

- Target screen: `scheduler.setHome("<id>")`. The sketch wakes from sleep into home, so the target shows from the first seconds.
- Needed state: set it right after creation, e.g. `timer = new CoreTimer(); timer.turn(25, 0); timer.startNow(0);`.

## 3. Run

```bash
rm -rf capture && timeout 120 /Applications/Processing.app/Contents/MacOS/Processing cli --sketch="$PWD" --run 2>&1 | grep -v "non-AWT\|AWT disabled\|writable" | tail -20; ls capture
```

(Windows: `"C:\Program Files\Processing\Processing.exe"`.) Check the log for exceptions and `[tag]` errors.

## 4. Look

Read every `capture/frame_NNNN.png`. When a Figma frame is the reference, get its screenshot and compare side by side: positions in px, gaps between rows, glyph heights, colours, stroke widths. List every difference you see. "Looks close" doesn't count as a finding.

## 5. Restore

```bash
cp $S/config.bak data/config.json && cp $S/cf_display.bak cf_display.pde && rm -rf capture && git diff --stat cf_display.pde
```

Done when `git diff --stat cf_display.pde` shows only the changes that belong to the actual task.
