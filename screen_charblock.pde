// Demo of character blocks (char_block.pde): one full-screen block built from components.
// Intro: Cells appear in random order. Main: the braille loader and spinner animate.
// Outro: rows disappear from the bottom up.
// Placeholder content until the calendar screen is rebuilt in this style.

class ScreenCharBlock extends CoreScreen {

  final float INTRO_LENGTH = 1.2;
  final float MAIN_LENGTH = 8.0;
  final float OUTRO_LENGTH = 0.8;

  final float MARGIN = 24;        // pixels around the block
  final float LINE_HEIGHT = 1.3;  // row height relative to the font size

  CharBlock block;
  HeaderLine header;
  ArrayList<DemoEntry> entries = new ArrayList<DemoEntry>();
  BrailleNoise loader;
  CharAnimationView spinner;

  RevealRandom reveal = new RevealRandom();
  RevealLines hide = new RevealLines();

  void start() {
    int cols = floor((width - 2 * MARGIN) / charCellWidth(fontChar));
    int rows = floor((height - 2 * MARGIN) / charCellHeight(fontChar, LINE_HEIGHT));
    block = new CharBlock(fontChar, cols, rows, LINE_HEIGHT);

    header = new HeaderLine(cols);
    int entryWidth = cols - 4;
    entries.add(new DemoEntry(entryWidth, true, "09:00", "Daily stand-up", "1 h", "12 MINUTES"));
    entries.add(new DemoEntry(entryWidth, false, "10:30", "Product roadmap review", "30 min", null));
    entries.add(new DemoEntry(entryWidth, false, "13:00", "Internal HR call with a title too long to fit on one row", "1 h 30 min", null));
    loader = new BrailleNoise(4, 2, 0.1, GREEN);
    spinner = new CharAnimationView(animSpinner, GREEN);
  }

  void drawIntro() {
    writeBlock();
    reveal.apply(block, tl.progress(0, INTRO_LENGTH));
    drawBlock();
    if (tl.t() >= INTRO_LENGTH) nextPhase();
  }

  void drawMain() {
    writeBlock();
    drawBlock();
    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    writeBlock();
    hide.apply(block, 1 - tl.progress(0, OUTRO_LENGTH));
    drawBlock();
    if (tl.t() >= OUTRO_LENGTH) nextPhase();
  }

  /** All components write their Cells. Entries stack from row 2, one empty row apart. */
  void writeBlock() {
    block.clear();
    block.place(header, 0, 0);

    int row = 2;
    for (DemoEntry entry : entries) {
      block.place(entry, 4, row);
      row += entry.h + 1;
    }

    // The screen can also write straight into the block, in block coordinates
    int bottom = block.rows - 2;
    int afterVersion = block.put(0, bottom, "Ver. 0.1263-A ", GREEN);
    block.place(loader, afterVersion, bottom);
    block.place(spinner, block.cols - spinner.w, block.rows - spinner.h);
  }

  void drawBlock() {
    background(BACKGROUND);
    block.draw(MARGIN, MARGIN);
  }
}

/** "── TODAY ◢ 21.10.2026 ────────…" across the whole row. */
class HeaderLine extends CharComponent {
  final String date = fmtDate(LocalDate.now());   // read once: the screen lasts seconds, not days

  HeaderLine(int w) {
    super(w, 1);
  }

  void write(CharBlock block) {
    int col = block.put(0, 0, "── TODAY ◢ " + date + " ", GREEN);
    block.putRepeated(col, 0, w - col, '─', GREEN);
  }
}

/**
 * Three rows:  ▶ 09:00  12 MINUTES ............ 1 h
 *                Daily stand-up
 *                ///~~~~///
 */
class DemoEntry extends CharComponent {
  final boolean isNext;   // the next event: white time badge, like in the Figma
  final String time, title, duration, badge;   // badge may be null

  DemoEntry(int w, boolean isNext, String time, String title, String duration, String badge) {
    super(w, 3);
    this.isNext = isNext;
    this.time = time;
    this.title = title;
    this.duration = duration;
    this.badge = badge;
  }

  void write(CharBlock block) {
    block.put(0, 0, "▶", GREEN);
    int col = block.putInverted(2, 0, " " + time + " ", isNext ? WHITE : GREEN);
    if (badge != null) col = block.putInverted(col + 1, 0, " ◷ " + badge + " ", YELLOW);

    // Dot leader up to the right-aligned duration
    int durationCol = w - duration.length();
    block.putRepeated(col + 1, 0, durationCol - col - 2, '.', GREEN);
    block.put(durationCol, 0, duration, GREEN);

    block.put(2, 1, title, GREEN);   // too long: the component's edge cuts it off
    block.put(2, 2, "///~~~~///", RED);
  }
}
