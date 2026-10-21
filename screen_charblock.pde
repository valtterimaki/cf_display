// Demo of character blocks (char_block.pde): one full-screen block built from components,
// laid out like the calendar in the Figma design, with made-up events.
// Intro: Cells appear in runs of random length. Main: the braille loader and spinner animate.
// Outro: rows disappear from the bottom up.
// Placeholder content until the calendar screen is rebuilt in this style.

class ScreenCharBlock extends CoreScreen {

  final float MAIN_LENGTH = 8.0;
  final float OUTRO_LENGTH = 0.8;

  final float MARGIN = 24;        // pixels around the block
  final float LINE_HEIGHT = 1.0;  // the font's own line height, as in the Figma

  CharBlock block;
  HeaderLine header;
  ArrayList<DemoEntry> entries = new ArrayList<DemoEntry>();
  OverlapRow overlap;
  BrailleNoise loader;
  CharAnimationView spinner;

  RevealChunks reveal = new RevealChunks(3, 16, 0.01, 0.4);   // 4–24 Cells every 10–400 ms
  RevealLines hide = new RevealLines();

  void start() {
    int cols = floor((width - 2 * MARGIN) / fontChar.cellWidth());
    int rows = floor((height - 2 * MARGIN) / fontChar.cellHeight(LINE_HEIGHT));
    block = new CharBlock(fontChar, cols, rows, LINE_HEIGHT);

    header = new HeaderLine(cols);
    int entryWidth = cols - 2;
    //                       width       next   time     title                     duration      badge         call   overlaps next
    entries.add(new DemoEntry(entryWidth, true,  "09:00", "DAILY STAND-UP",         "1 h",        "12 MINUTES", false, false));
    entries.add(new DemoEntry(entryWidth, false, "10:30", "PRODUCT ROADMAP REVIEW", "30 min",     null,         false, false));
    entries.add(new DemoEntry(entryWidth, false, "13:00", "INTERNAL HR CALL",       "1 h 30 min", null,         true,  true));
    entries.add(new DemoEntry(entryWidth, false, "14:00", "DESIGN CRITIQUE",        "1 h 30 min", null,         false, false));
    overlap = new OverlapRow(cols - 5);
    loader = new BrailleNoise(4, 2, 0.1, GREEN);
    spinner = new CharAnimationView(animSpinner, GREEN);
  }

  void drawIntro() {
    writeBlock();
    reveal.apply(block, tl.t());
    drawBlock();
    if (reveal.isDone()) nextPhase();
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

  /**
   * All components write their Cells. Entries stack from row 2 with an empty row
   * between them, or an overlap row when two events overlap.
   */
  void writeBlock() {
    block.clear();
    block.place(header, 0, 0);

    int row = 2;
    for (DemoEntry entry : entries) {
      block.place(entry, 2, row);
      row += entry.h;
      if (entry.overlapsNext) block.place(overlap, 5, row);
      row += 1;
    }
    // The screen can also write straight into the block, in block coordinates
    block.put(5, row, "░   END", GREEN);

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

/** "─┄ TODAY◢ 28.3.2026 ┄┄──────…" across the whole row. */
class HeaderLine extends CharComponent {
  final String date = fmtDate(LocalDate.now());   // read once: the screen lasts seconds, not days

  HeaderLine(int w) {
    super(w, 1);
  }

  void write(CharBlock block) {
    int col = block.put(0, 0, "─┄ TODAY◢ " + date + " ┄┄", GREEN);
    block.putRepeated(col, 0, w - col, '─', GREEN);
  }
}

/**
 * Two rows (𜴳 only when the event has a call):
 *   𜴳 ░ 🞂  09:00   🕓12 MINUTES ............1 h
 *      ░    DAILY STAND-UP
 */
class DemoEntry extends CharComponent {
  final boolean isNext;         // the next event: white time badge
  final String time, title, duration;
  final String badge;           // yellow badge after the time, or null
  final boolean hasCall;        // a Teams call is attached
  final boolean overlapsNext;   // read by the screen: an overlap row follows

  DemoEntry(int w, boolean isNext, String time, String title, String duration, String badge,
            boolean hasCall, boolean overlapsNext) {
    super(w, 2);
    this.isNext = isNext;
    this.time = time;
    this.title = title;
    this.duration = duration;
    this.badge = badge;
    this.hasCall = hasCall;
    this.overlapsNext = overlapsNext;
  }

  void write(CharBlock block) {
    if (hasCall) block.put(0, 0, "𜴳", WHITE);
    block.put(3, 0, "░", GREEN);
    block.put(3, 1, "░", GREEN);
    block.put(5, 0, "🞂", GREEN);

    int col = block.putInverted(6, 0, " " + time + " ", isNext ? WHITE : GREEN);
    if (badge != null) {
      // The badge's own end padding separates it from the dots
      col = block.putInverted(col + 1, 0, " 🕓" + badge + " ", YELLOW);
    } else {
      col += 1;
    }

    // Dot leader up to the right-aligned duration
    int durationCol = w - duration.length();
    block.putRepeated(col, 0, durationCol - col, '.', GREEN);
    block.put(durationCol, 0, duration, GREEN);

    block.put(7, 1, title, GREEN);   // too long: the component's edge cuts it off
  }
}

/** "🮙🮙🮙 OVERLAP 🮙🮙🮙" in red, between two overlapping events. */
class OverlapRow extends CharComponent {

  OverlapRow(int w) {
    super(w, 1);
  }

  void write(CharBlock block) {
    int col = block.put(0, 0, "🮙🮙🮙", RED);
    col = block.putInverted(col, 0, " OVERLAP ", RED);
    block.put(col, 0, "🮙🮙🮙", RED);
  }
}
