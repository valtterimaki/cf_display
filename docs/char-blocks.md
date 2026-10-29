# Character blocks

Grids of monospace characters (terms in [GLOSSARY.md](../GLOSSARY.md): Block, Cell,
Component, Inverted, Block effect, Character animation). All in `char_block.pde`;
`screen_calendar.pde` is the first screen built with it.

- A screen creates a `CharBlock` and its `CharComponent`s in `start()`. Every frame:
  `block.clear()` → `block.place(component, col, row)` for each → `effect.apply(block, progress)`
  → `block.draw(x, y)`. Stacking is a loop with a row counter in the screen, no layout engine.
- Components write with `put`, `putInverted`, `putRepeated`, `set` in their own coordinates;
  writes outside their size are dropped (long text is cut off). Continuous animation uses `now()`.
- Block effects are small reusable classes (the exception to hand-crafted animations); the
  screen still decides when they run and passes their progress.
- Cell colors: palette constants in `ui_assets.pde` (`GREEN`, `YELLOW`...) or any `color`.
  Background 0 = none. Inverted characters use the block's background, else `BACKGROUND`.
- Font: a custom Iosevka with "Term" spacing in `data/fonts/`, loaded as a `CharFont` with
  `loadCharFont(file, size)`: every glyph exactly one cell, so there is no wide-character
  handling. `[assets]` logs glyphs wider than a cell: must be 0.
- Only listed characters draw: `charBlockCharset()` for U+0000–FFFF (Processing fonts),
  `charBlockExtraRanges()` for symbols above U+FFFF (🞂 🕓, legacy computing sextants and
  octants). PFont can't draw those, so `CharFont` draws them into one image at load and Cells
  hold Private Use Area stand-ins. Write the real characters in code: `put(0, 0, "🞂 09:00", c)`.
- Font sizes in code: `getDefaultSize()` (sketch pixels), not `getSize()` (2× on Retina).
  Vertical metrics: the font file's line height (`CharFont.lineAscent/lineDescent`), not
  PFont's `ascent()/descent()` (measured from 'd' and 'p', too short). Block `lineHeight` 1.0 =
  the font's line height, Figma's "auto": block glyphs (░ █ 🮙) of neighbouring rows touch.
- Character animations: `data/anim/<name>.txt`, frames separated by a `---` line, loaded in
  `loadAssets()` with `loadCharAnimation(name, fps, loop)`, played by `CharAnimationView`.
- Debug: `charBlockSelfCheck()` runs at startup when debug is on; the debug view shows
  block draw time ("blocks … ms"): the number to watch on the Pi 3B.
