# cf_display

A desk info display: screens of information and animation shown one after another on a 720×720 screen.

## Character graphics

**Block**:
A rectangular grid of characters placed somewhere on a screen, drawn in one monospace font at one size.
_Avoid_: Grid, canvas, text area

**Cell**:
One character slot in a Block, at a column and row; holds a character and its colors.
_Avoid_: Slot, tile, pixel

**Component**:
A reusable part placed at a column and row inside a Block that fills some of its Cells (an event entry, a header line, a braille loader).
_Avoid_: Widget, element, module

**Inverted**:
A Cell drawn as a solid colored background with its character cut out in the background color.
_Avoid_: Highlighted, reversed

**Block effect**:
A reusable change applied to a Block's Cells after Components have written them and before the Block is drawn (a line-by-line reveal, a glitch).
_Avoid_: Transition (that is the animation between two screens), filter

**Character animation**:
A frame-by-frame animation made of rows of characters, read from a text file in `data/`.
_Avoid_: ASCII animation, sprite, video (that is a frame sequence of images)
