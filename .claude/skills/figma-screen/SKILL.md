---
name: figma-screen
description: Build or update a screen from a Figma design. Use when the owner shares a figma.com/design link for a screen, widget or layout, or asks to match the code to Figma.
---

The Figma file is `r6JVC4sJwe4fon9lUSjPGu` (cf_display). Layer names describe intent ("Home clock", "timer arc"); the owner names layers for you to read.

## 1. Read the design

Load `figma:figma-design-to-code`, then create a session, read the node's design context and screenshot. Read the topic doc for the area (CLAUDE.md "Topic docs") and the screen's current `.pde`.

## 2. Explain, then ask

Tell the owner, compactly, how you read the design: what each part is, what moves, what depends on data. Then list everything unclear as **numbered questions**. They answer as "1. … 2. …". Typical gaps:

- behaviour with no data, too much data, or an error
- what animates, how long, which ease
- what's real content and what's decoration to fake for now

Wait for the answers before writing code. Anything to design later goes to PLAN.md §5 Open issues, not into code.

## 3. Map Figma to the sketch

- Frame = 720×720 px, 1:1 with the canvas. Use the Figma numbers as they are.
- Text in the char font / character grid → `char_block.pde` (see docs/char-blocks.md). Other drawing → plain Processing in the screen's `draw*()`.
- Every font size gets its own `PFont` in `loadAssets()` (`ui_assets.pde`). Screens call `textFont()`, never `textSize()`.
- Colours: use the named colours in `ui_assets.pde`, and add one there if the design brings a new colour.
- Motion: `tl.progress(start, dur)` + `CoreEase.*`. An ease given as a CSS name or curve becomes `CoreEase.cubicBezier(x1, y1, x2, y2, x)` with numbers from cubic-bezier.com. Durations in seconds, as named constants at the top of the screen.
- Values that jump in the design (clock hands, ticks) jump in code too. Animate only what the owner asked to animate.

## 4. Build and look

Run `scripts/check.sh` until it shows `[check] ok`, then use the `look` skill with the Figma screenshot as the reference. Fix every difference it lists and look again. Done when the capture matches the Figma frame, or each remaining difference has been reported to the owner.

## 5. Tweak loop

The owner tunes by eye ("300 ms, expo out", "2 px thinner, 1 px in"). Change exactly that, check, look, report in one or two lines. Commit only when asked: one commit, `Area: what` message (e.g. `Home: analog clock with timer arc (Figma "Home clock")`).
