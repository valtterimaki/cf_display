# CRT effect

Every finished frame is encoded into an analogue PAL (or NTSC) composite TV signal and
decoded again, one pixel row per scan line. Colour bleed, colour shifted right of
edges, dot crawl and rainbow cross-colour come out of the signal itself; nothing is
drawn on top (no scanlines, masks, curvature or glow).

## Files

- `data/shaders/crt.frag`: the shader (GLSL ES 1.00, runs on the Pi and the desktop)
- `fx_crt.pde`: compiles it, sets its values, runs it with `filter()`, draws the panel
- `CoreCrt.java`: the settings, their limits, load/save, filter weights
- `data/crt.json`: the settings. Committed, so a look tuned on one machine reaches the others

In `draw()`: screens → `drawCrt()` → debug overlay → CRT panel. The debug texts and the
panel stay sharp; captures include the effect.

## Tuning

**C** opens the panel (any hardware, so a USB keyboard works on the Pi too).
Up/Down select, Left/Right change, R back to default, S save to `data/crt.json`.
Other keys keep working, e.g. number keys to look at other screens.
Over SSH: edit `data/crt.json`, restart the sketch. `"enabled": 0` turns it off (costs nothing then).

| Setting | Effect |
|---|---|
| `enabled` | on/off |
| `pal` | 1 = PAL (fine dots), 0 = NTSC (coarse checkerboard) |
| `taps` | filter width. **Texture reads per pixel = 2 × taps + 1: the speed knob** |
| `chromaBlur` | colour bleed width, px (at most taps / 2) |
| `chromaDelay` | colour shifted right of edges, px (at most taps − 2) |
| `leak` | dot crawl strength; higher is also sharper |
| `chromaGain` | saturation |
| `hue` | tint, degrees |
| `nonlin` | brightness-dependent hue/saturation error |
| `noise` | RF snow |
| `clipHi` | limits bright saturated yellow/cyan |

`taps` and `pal` recompile the shader (they are loop bounds and `#if`s in GLSL ES 1.00);
the rest are uniforms. Limits that depend on `taps` show as "(max …)" in the panel.

## How it stays cheap

The signal is sampled at exactly 4 samples per subcarrier cycle (the "4fsc" trick), so the
subcarrier's cos/sin are only 1, 0 or −1: no trig. The tap loop is unrolled, so each tap's
phase is known when compiling, and each tap is 1 texture read + 1 dot product + a few
multiply-adds. The filter weights come from Java as uniform arrays (no `exp()` per pixel).
Colour and brightness filters share the same reads. At `taps` 6 that's 13 reads per pixel;
the original prototype read 18 for the same, pixel-identical, picture.

The 4fsc trick makes the subcarrier 3.42 MHz instead of PAL's 4.43 (dot pitch differs a
bit from a real set; nothing else changes).

## Pi 3B

Not measured yet. The GPU budget at 720×720 × 50 fps is roughly 10–14 reads per pixel,
so expect `taps` 4–6 to be the range to try. Steps when the Pi runs:

1. Debug view (D) fps with `enabled` 0, then `taps` 2, 4, 6. Two readings give the fixed
   cost and the cost per tap.
2. Not enough even at low taps → options, best first: 25 fps (`FRAME_RATE`, but the videos
   are 50 fps), or turn it off.
3. `filter()` copies the screen to a texture once per frame. If that copy shows up as a
   big fixed cost, screens could draw into an offscreen buffer instead.

## Gotchas

- The Mac runs at `pixelDensity(1)` (set in `settings()`): at Processing 4.5's default 2
  the effect would run at 1440 px, with half-size dots and 4× the cost.
- Shader compile errors in Processing can leave a hung window. `sample` is a reserved
  word in desktop GLSL: don't name functions that.
- Thin text smears (1 px strokes carry detail beyond the signal's bandwidth). That's the
  look. Text that must stay readable: thicker strokes, lower `chromaBlur`, higher `leak`.
- Single colour on black barely bleeds sideways (little colour to smear); coloured edges do.
