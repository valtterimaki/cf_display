// Character blocks: grids of monospace characters built from components.
// Terms (see GLOSSARY.md):
//   Block        — a grid of Cells, drawn by a screen at a pixel position
//   Cell         — one character with a text color and a background color (0 = none)
//   Component    — a reusable part that writes into some of the Cells each frame
//   Block effect — changes the Cells after the components and before drawing
//
// Every frame a screen does:
//   block.clear();
//   block.place(header, 0, 0);                 // components write their Cells
//   reveal.apply(block, tl.progress(0, 1.2));  // optional Block effects
//   block.draw(x, y);
//
// The font must use Iosevka's "Term" spacing: every glyph exactly one cell wide.
// The [assets] log line counts glyphs wider than a cell — it should say 0.

// Font sizes are read with getDefaultSize(): the size in sketch pixels. getSize() is
// doubled on high-density (Retina) screens, where glyph images are made at 2× size.

/** Pixel width of one cell: the font's character width. */
float charCellWidth(PFont font) {
  return round(font.width('M') * font.getDefaultSize());
}

/** Pixel height of one row. lineHeight 1.0 = the font size; more spaces the rows out. */
float charCellHeight(PFont font, float lineHeight) {
  return round(lineHeight * font.getDefaultSize());
}

class CharBlock {
  // Naming trap: a method in a .pde class hides every sketch function with the same name
  // inside the class, so a CharBlock.fill() would break fill(color) in draw(). clear(),
  // set() and draw() share names with Processing functions too, but this class never
  // calls the sketch versions. Don't add a method named after one it does call.

  final PFont font;
  final int cols, rows;
  final float cellWidth, cellHeight;
  color background = 0;   // 0 = none: only the Cells are drawn

  // One entry per Cell, row by row. Block effects may read these directly.
  final char[] chars;
  final color[] fg;
  final color[] bg;

  // Where writes currently go: the component being placed, or the whole block.
  int areaCol, areaRow, areaWidth, areaHeight;

  CharBlock(PFont font, int cols, int rows, float lineHeight) {
    this.font = font;
    this.cols = cols;
    this.rows = rows;
    cellWidth = charCellWidth(font);
    cellHeight = charCellHeight(font, lineHeight);
    chars = new char[cols * rows];
    fg = new color[cols * rows];
    bg = new color[cols * rows];
    useWholeBlock();
    clear();
  }

  void clear() {
    java.util.Arrays.fill(chars, ' ');
    java.util.Arrays.fill(fg, 0);
    java.util.Arrays.fill(bg, 0);
  }

  /** Lets the component write with (0, 0) at col, row. Writes outside its size are dropped. */
  void place(CharComponent component, int col, int row) {
    areaCol = col;
    areaRow = row;
    areaWidth = component.w;
    areaHeight = component.h;
    component.write(this);
    useWholeBlock();
  }

  // --- writing (coordinates relative to the area: the component, or the whole block) ---

  /** Writes text from col to the right. Returns the column after it. */
  int put(int col, int row, String text, color textColor) {
    return put(col, row, text, textColor, 0);
  }

  int put(int col, int row, String text, color textColor, color backgroundColor) {
    for (int i = 0; i < text.length(); i++) {
      set(col + i, row, text.charAt(i), textColor, backgroundColor);
    }
    return col + text.length();
  }

  /** Solid fillColor behind the text, characters cut out in the background color. */
  int putInverted(int col, int row, String text, color fillColor) {
    return put(col, row, text, cutoutColor(), fillColor);
  }

  /** The same character count times, e.g. a dot leader or a line of dashes. */
  int putRepeated(int col, int row, int count, char ch, color textColor) {
    for (int i = 0; i < count; i++) set(col + i, row, ch, textColor, 0);
    return col + max(0, count);
  }

  /** Changes one Cell. Anything outside the area or the block is ignored. */
  void set(int col, int row, char ch, color textColor, color backgroundColor) {
    if (col < 0 || row < 0 || col >= areaWidth || row >= areaHeight) return;
    int c = areaCol + col;
    int r = areaRow + row;
    if (c < 0 || r < 0 || c >= cols || r >= rows) return;   // area sticks out of the block
    int i = r * cols + c;
    chars[i] = ch;
    fg[i] = textColor;
    bg[i] = backgroundColor;
  }

  // --- drawing ---

  void draw(float x, float y) {
    long startNanos = System.nanoTime();
    pushStyle();
    noStroke();

    // Whole pixels keep the glyphs sharp and the backgrounds free of seams
    int left = round(x);
    int top = round(y);

    if (background != 0) {
      fill(background);
      rect(left, top, cols * cellWidth, rows * cellHeight);
    }

    // Backgrounds first, one rect per run of same-colored Cells,
    // so neighbouring inverted Cells touch without hairline gaps.
    for (int r = 0; r < rows; r++) {
      int c = 0;
      while (c < cols) {
        color runColor = bg[r * cols + c];
        int end = c + 1;
        while (end < cols && bg[r * cols + end] == runColor) end++;
        if (runColor != 0) {
          fill(runColor);
          rect(left + c * cellWidth, top + r * cellHeight, (end - c) * cellWidth, cellHeight);
        }
        c = end;
      }
    }

    // Glyphs centered vertically in the row
    textFont(font);
    textAlign(LEFT, BASELINE);
    float size = font.getDefaultSize();
    float baseline = round((cellHeight - (font.ascent() + font.descent()) * size) / 2 + font.ascent() * size);

    // ponytail: one text() per character; draw same-color runs as one string if the Pi 3B is too slow
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int i = r * cols + c;
        if (chars[i] == ' ') continue;
        fill(fg[i]);
        text(chars[i], left + c * cellWidth, top + r * cellHeight + baseline);
      }
    }

    popStyle();
    debugBlockMillis += (System.nanoTime() - startNanos) / 1e6;
  }

  // --- internals ---

  void useWholeBlock() {
    areaCol = 0;
    areaRow = 0;
    areaWidth = cols;
    areaHeight = rows;
  }

  /** Inverted Cells show their character in the block's background, or the screen's if it has none. */
  color cutoutColor() {
    return background != 0 ? background : BACKGROUND;
  }
}

/**
 * A reusable part of a block: an event entry, a header line, a loader...
 * The screen creates it in start() and calls block.place(component, col, row) every frame.
 */
abstract class CharComponent {
  final int w, h;

  CharComponent(int w, int h) {
    this.w = w;
    this.h = h;
  }

  /** Write the Cells with block.put() etc. (0, 0) is this component's top-left corner. */
  abstract void write(CharBlock block);
}

// --- Block effects ---
// Run after the components have written and before block.draw().
// The screen owns the timing: it passes progress, usually from tl.progress().
// New idea for a reveal, glitch etc. = one more small class here.

abstract class BlockEffect {
  /** progress 1 = the block as written. Pass 1 - p to hide instead of reveal. */
  abstract void apply(CharBlock block, float progress);
}

/** Shows rows from the top down. */
class RevealLines extends BlockEffect {
  void apply(CharBlock block, float progress) {
    int visibleRows = floor(progress * block.rows);
    for (int r = visibleRows; r < block.rows; r++) {
      for (int c = 0; c < block.cols; c++) block.set(c, r, ' ', 0, 0);
    }
  }
}

/** Shows Cells one by one in random order (the order is picked once). */
class RevealRandom extends BlockEffect {
  IntList order;

  void apply(CharBlock block, float progress) {
    if (order == null) {
      order = new IntList();
      for (int i = 0; i < block.cols * block.rows; i++) order.append(i);
      order.shuffle();
    }
    int visible = floor(progress * order.size());
    for (int k = visible; k < order.size(); k++) {
      int i = order.get(k);
      block.set(i % block.cols, i / block.cols, ' ', 0, 0);
    }
  }
}

// --- shared components ---

/** Random braille characters, all changed every `interval` seconds. A loader or decoration. */
class BrailleNoise extends CharComponent {
  final float interval;
  final color textColor;
  final char[] cells;
  float nextChange = 0;

  BrailleNoise(int w, int h, float interval, color textColor) {
    super(w, h);
    this.interval = interval;
    this.textColor = textColor;
    cells = new char[w * h];
  }

  void write(CharBlock block) {
    if (now() >= nextChange) {
      // U+2800–U+28FF: every combination of the 8 braille dots
      for (int i = 0; i < cells.length; i++) cells[i] = (char) (0x2800 + int(random(256)));
      nextChange = now() + interval;
    }
    for (int i = 0; i < cells.length; i++) block.set(i % w, i / w, cells[i], textColor, 0);
  }
}

/** Plays a Character animation, starting when the component is created. */
class CharAnimationView extends CharComponent {
  final CharAnimation animation;
  final color textColor;
  final float startTime;

  CharAnimationView(CharAnimation animation, color textColor) {
    super(animation.w, animation.h);
    this.animation = animation;
    this.textColor = textColor;
    startTime = now();
  }

  void write(CharBlock block) {
    String[] frame = animation.frameAt(now() - startTime);
    for (int r = 0; r < h; r++) {
      // Pad short rows with spaces: editors strip trailing spaces, but the whole
      // animation area should still hide what's under it.
      int col = block.put(0, r, r < frame.length ? frame[r] : "", textColor);
      block.putRepeated(col, r, w - col, ' ', textColor);
    }
  }
}

// --- Character animations ---
// Text files in data/anim/<name>.txt: rows of characters, frames separated by a
// line containing only ---. Load them in loadAssets() with loadCharAnimation().

class CharAnimation {
  final ArrayList<String[]> frames;
  final float fps;
  final boolean loop;
  final int w, h;   // the largest frame

  CharAnimation(ArrayList<String[]> frames, float fps, boolean loop) {
    this.frames = frames;
    this.fps = fps;
    this.loop = loop;
    int maxWidth = 0;
    int maxHeight = 0;
    for (String[] frame : frames) {
      maxHeight = max(maxHeight, frame.length);
      for (String line : frame) maxWidth = max(maxWidth, line.length());
    }
    w = maxWidth;
    h = maxHeight;
  }

  /** The frame to show this many seconds after the start. Without loop it stays on the last frame. */
  String[] frameAt(float seconds) {
    int i = max(0, int(seconds * fps));
    i = loop ? i % frames.size() : min(i, frames.size() - 1);
    return frames.get(i);
  }
}

CharAnimation loadCharAnimation(String name, float fps, boolean loop) {
  String[] lines = loadStrings("anim/" + name + ".txt");
  if (lines == null) throw new RuntimeException("[assets] character animation not found: data/anim/" + name + ".txt");

  ArrayList<String[]> frames = new ArrayList<String[]>();
  ArrayList<String> frame = new ArrayList<String>();
  for (String line : lines) {
    if (line.equals("---")) {
      frames.add(frame.toArray(new String[0]));
      frame.clear();
    } else {
      frame.add(line);
    }
  }
  if (!frame.isEmpty()) frames.add(frame.toArray(new String[0]));
  return new CharAnimation(frames, fps, loop);
}

// --- font ---

/**
 * Every character a block may draw. createFont() makes all their glyphs up front:
 * glyphs made on first use would stall the sketch mid-animation.
 * Characters outside these ranges don't draw — add a range here when needed.
 */
char[] charBlockCharset() {
  int[][] ranges = {
    { 0x0020, 0x007E },   // ASCII
    { 0x00A0, 0x00FF },   // Latin-1 (ä, ö, °, ·)
    { 0x2010, 0x2027 },   // dashes, quotes, bullet, ellipsis
    { 0x2190, 0x21FF },   // arrows
    { 0x2300, 0x23FF },   // technical symbols
    { 0x2500, 0x259F },   // box drawing and block elements
    { 0x25A0, 0x25FF },   // geometric shapes (◢ ▶ ◷)
    { 0x2800, 0x28FF },   // braille
  };
  StringBuilder chars = new StringBuilder();
  for (int[] range : ranges) {
    for (int c = range[0]; c <= range[1]; c++) chars.append((char) c);
  }
  return chars.toString().toCharArray();
}

/** Glyphs wider than one cell. Should be 0 with a "Term" font. */
int countWideGlyphs(PFont font) {
  // Glyph widths are in getSize() pixels. + 1 allows for rounding to whole pixels.
  float limit = font.width('M') * font.getSize() + 1;
  int count = 0;
  for (int i = 0; i < font.getGlyphCount(); i++) {
    if (font.getGlyph(i).setWidth > limit) count++;
  }
  return count;
}

// --- self-check (run at startup when debug is on) ---

void charBlockSelfCheck() {
  CharBlock block = new CharBlock(fontChar, 10, 4, 1.0);

  // A 3×1 component at column 2, row 1, writing partly outside itself
  block.place(new CharComponent(3, 1) {
    void write(CharBlock b) {
      b.put(-1, 0, "abcde", WHITE);
      b.put(0, 1, "x", WHITE);   // below the component
    }
  }, 2, 1);
  selfCheck(block.chars[1 * 10 + 1] == ' ', "write left of a component is dropped");
  selfCheck(new String(block.chars, 1 * 10 + 2, 3).equals("bcd"), "component writes at its own (0, 0)");
  selfCheck(block.chars[1 * 10 + 5] == ' ', "write right of a component is dropped");
  selfCheck(block.chars[2 * 10 + 2] == ' ', "write below a component is dropped");

  // Whole-block writes past the edge, and a component partly off the left edge
  selfCheck(block.put(8, 3, "abc", WHITE) == 11, "put returns the next column");
  selfCheck(new String(block.chars, 3 * 10 + 8, 2).equals("ab"), "write past the block edge is dropped");
  block.place(new CharComponent(2, 1) {
    void write(CharBlock b) {
      b.put(0, 0, "yz", WHITE);
    }
  }, -1, 0);
  selfCheck(block.chars[0] == 'z', "component partly off the block keeps its visible part");

  println("[charblock] self-check ok");
}

void selfCheck(boolean ok, String what) {
  if (!ok) throw new RuntimeException("[charblock] self-check failed: " + what);
}
