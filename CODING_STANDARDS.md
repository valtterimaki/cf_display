# Coding standards

The rules a review checks a change against. Architecture rules (what goes in `.pde` vs
`.java`, file prefixes, how data flows) are in [CLAUDE.md](CLAUDE.md). Mechanical rules are
enforced by `scripts/check.sh` and not repeated here.

## Readable for a hobbyist

The owner is a hobbyist coder: code is clean and professional but easy to read.

- Clear names. Short comments that explain *why*, as dense as the surrounding code's.
- Boring over clever: no tricks a reader has to decode.
- No unnecessary abstraction: no interface with one implementation, no generic system
  for one use, no config for a value that never changes.
- Animations are hand-crafted per screen from timing building blocks (`CoreTimeline`,
  `CoreEase`), not generic effect systems. Block effects are the one exception
  ([docs/char-blocks.md](docs/char-blocks.md)).

## Processing

- Drawing that sits on top of screens, or changes style that later drawing relies on
  (`strokeWeight`, `strokeJoin`, `textAlign`...), is wrapped in `pushStyle()`/`popStyle()`.
- Displayed numbers and times go through `ui_helpers.pde` (`fmtDecimal`, `fmtTemperature`,
  `fmtTime`, `fmtDuration`): locale-independent, so PC (Finnish locale), Mac and Pi match.
- Fonts come from `loadAssets()`, one `PFont` per size, selected with `textFont()`.
- Logging: `System.out.println("[tag] message")` with tags like `[screen]`, `[scheduler]`,
  `[data]`, `[trigger]`, `[hw]`, `[input]`, `[config]`, `[assets]`.
- Desktop vs Pi differences go through config switches (`"hardware"` etc.), never through
  code commented in or out.
