// Calendar: today's remaining events as a character block, like the Figma design.
//   ─┄ TODAY◢ 22.10.2026 ┄┄─────────────
//      ░ 🞂  09:00   🕓12 MINUTES ......1 h
//      ░    DAILY STAND-UP
// Intro: Cells appear in runs of random length. Outro: rows disappear from the bottom up.

class ScreenCalendar extends CoreScreen {

  final float MAIN_LENGTH = 10.0;
  final float OUTRO_LENGTH = 0.8;

  final float MARGIN = 24;        // pixels around the block
  final float LINE_HEIGHT = 1.0;  // the font's own line height, as in the Figma
  final int FIRST_ROW = 2;        // entries start below the header and one empty row

  CharBlock block;
  CalendarHeader header;
  ArrayList<CalendarEntry> entries = new ArrayList<CalendarEntry>();
  int hiddenCount = 0;            // events that didn't fit: "+N MORE"
  boolean loading = false;        // no calendar fetched yet
  OverlapRow overlap;
  BrailleNoise loader;

  RevealChunks reveal = new RevealChunks(4, 24, 0.05, 0.1);   // 4–24 Cells every 50–100 ms
  RevealLines hide = new RevealLines();

  void start() {
    int cols = floor((width - 2 * MARGIN) / fontChar.cellWidth());
    int rows = floor((height - 2 * MARGIN) / fontChar.cellHeight(LINE_HEIGHT));
    block = new CharBlock(fontChar, cols, rows, LINE_HEIGHT);
    header = new CalendarHeader(cols);
    overlap = new OverlapRow(cols - 5);
    loader = new BrailleNoise(4, 1, 0.1, GREEN);

    // A snapshot: rows don't jump around mid-animation if new data arrives
    DataCalendar calendar = store.calendar();
    if (calendar == null) {
      loading = true;
      return;
    }
    java.util.List<DataCalendar.Event> events = calendar.remainingToday(LocalDateTime.now());

    // As many entries as fit, leaving one row for END / +N MORE.
    // Each entry takes its 2 rows plus 1 (empty or overlap) below it.
    int row = FIRST_ROW;
    for (DataCalendar.Event event : events) {
      if (row + CalendarEntry.HEIGHT >= rows) break;
      entries.add(new CalendarEntry(cols - 2, event, entries.isEmpty()));
      row += CalendarEntry.HEIGHT + 1;
    }
    hiddenCount = events.size() - entries.size();
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
   * All components write their Cells. Entries stack with an empty row between them,
   * or an overlap row when an event is still on when the next one starts.
   */
  void writeBlock() {
    block.clear();
    block.place(header, 0, 0);

    if (loading) {
      int col = block.put(5, FIRST_ROW, "░   LOADING ", GREEN);
      block.place(loader, col, FIRST_ROW);
      return;
    }

    int row = FIRST_ROW;
    for (int i = 0; i < entries.size(); i++) {
      CalendarEntry entry = entries.get(i);
      block.place(entry, 2, row);
      row += entry.h;
      boolean overlapsNext = i + 1 < entries.size() && entry.event.end.isAfter(entries.get(i + 1).event.start);
      if (overlapsNext) block.place(overlap, 5, row);
      row += 1;
    }

    if (entries.isEmpty()) {
      block.put(5, row, "░   NO MORE EVENTS TODAY", GREEN);
      row += 2;
    }
    block.put(5, row, hiddenCount > 0 ? "░   +" + hiddenCount + " MORE" : "░   END", GREEN);
  }

  void drawBlock() {
    background(BACKGROUND);
    block.draw(MARGIN, MARGIN);
  }
}

/** "─┄ TODAY◢ 22.10.2026 ┄┄──────…" across the whole row. */
class CalendarHeader extends CharComponent {
  final String date = fmtDate(LocalDate.now());   // read once: the screen lasts seconds, not days

  CalendarHeader(int w) {
    super(w, 1);
  }

  void write(CharBlock block) {
    int col = block.put(0, 0, "─┄ TODAY◢ " + date + " ┄┄", GREEN);
    block.putRepeated(col, 0, w - col, '─', GREEN);
  }
}

/**
 * One event, two rows (𜴳 only when a call is attached):
 *   𜴳 ░ 🞂  09:00   🕓12 MINUTES ............1 h
 *      ░    DAILY STAND-UP
 */
class CalendarEntry extends CharComponent {
  static final int HEIGHT = 2;
  final int SOON_MINUTES = 60;   // the time-until badge shows this long before the start

  final DataCalendar.Event event;
  final boolean isFirst;         // the next or current event: white time, may get the badge

  CalendarEntry(int w, DataCalendar.Event event, boolean isFirst) {
    super(w, HEIGHT);
    this.event = event;
    this.isFirst = isFirst;
  }

  void write(CharBlock block) {
    if (event.hasCall) block.put(0, 0, "𜴳", WHITE);
    block.put(3, 0, "░", GREEN);
    block.put(3, 1, "░", GREEN);
    block.put(5, 0, "🞂", GREEN);

    int col = block.putInverted(6, 0, " " + fmtTime(event.start) + " ", isFirst ? WHITE : GREEN);
    String badge = isFirst ? badgeText() : null;
    if (badge != null) {
      // The badge's own end padding separates it from the dots
      col = block.putInverted(col + 1, 0, " " + badge + " ", YELLOW);
    } else {
      col += 1;
    }

    // Dot leader up to the right-aligned duration
    String duration = fmtDuration(event.start, event.end);
    int durationCol = w - duration.length();
    block.putRepeated(col, 0, durationCol - col, '.', GREEN);
    block.put(durationCol, 0, duration, GREEN);

    block.put(7, 1, event.title.toUpperCase(), GREEN);   // too long: the component's edge cuts it off
  }

  /** "NOW", "🕓12 MINUTES" or null. Worked out every frame, so it counts down live. */
  String badgeText() {
    long seconds = java.time.Duration.between(LocalDateTime.now(), event.start).getSeconds();
    if (seconds <= 0) return "NOW";
    long minutes = (seconds + 59) / 60;   // rounded up: "1 MINUTE" lasts until it starts
    if (minutes > SOON_MINUTES) return null;
    return "🕓" + minutes + (minutes == 1 ? " MINUTE" : " MINUTES");
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
