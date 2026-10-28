// Calendar, like the Figma design: a timeline of the whole day on top, drawn with
// shapes, and below it today's remaining events as a character block.
//   |  ¦  |  ¦  |  ¦  |  ¦  |      ← 08:00–18:00, a tick every half hour
//     ▬▬▬▬   ▬▬        ▬▬▬▬▬▬      ← one bar per event, overlapping ones in lanes below
//   ─┄ TODAY◢ 22.10.2026 ┄┄─────────────
//      ░ 🞂  09:00   🕓12 MINUTES ......1 h
//      ░    DAILY STAND-UP
// Intro: Cells appear in runs of random length. Outro: rows disappear from the bottom up.
// The timeline isn't animated yet.

class ScreenCalendar extends CoreScreen {

  final float MAIN_LENGTH = 10.0;
  final float OUTRO_LENGTH = 0.8;

  final float MARGIN = 24;        // pixels left of the block
  final float BLOCK_TOP = 310;    // the block runs from here to the bottom of the screen
  final float LINE_HEIGHT = 1.0;  // the font's own line height, as in the Figma
  final int FIRST_ROW = 2;        // entries start below the header and one empty row

  // Timeline geometry from the Figma. Events before 08:00 or after 18:00 are drawn
  // past the ends of the grid, even off the screen.
  final int TIMELINE_FIRST_HOUR = 8;
  final int TIMELINE_LAST_HOUR = 18;
  final float TIMELINE_LEFT = 64;   // x of 08:00
  final float TIMELINE_TOP = 170;   // top of the now marker; ticks and bars are placed from here
  final float HOUR_WIDTH = 48;
  final float BAR_HEIGHT = 12;
  final float LANE_STEP = 14;       // bar height + gap

  CharBlock block;
  final String date = fmtDate(LocalDate.now());   // read once: the screen lasts seconds, not days
  final LocalDateTime timelineStart = LocalDate.now().atTime(TIMELINE_FIRST_HOUR, 0);
  java.util.List<DataCalendar.Event> timelineEvents = new ArrayList<DataCalendar.Event>();
  int[] lanes = new int[0];       // lane of each timeline event, 0 = top
  ArrayList<CalendarEntry> entries = new ArrayList<CalendarEntry>();
  int hiddenCount = 0;            // events that didn't fit: "+N MORE"
  boolean loading = false;        // no calendar fetched yet
  BrailleNoise loader;

  RevealChunks reveal = new RevealChunks(3, 18, 0.01, 0.3);   // 3–18 Cells every 10–300 ms
  RevealLines hide = new RevealLines();

  void start() {
    int cols = floor((width - 2 * MARGIN) / fontChar.cellWidth());
    int rows = floor((height - BLOCK_TOP) / fontChar.cellHeight(LINE_HEIGHT));
    block = new CharBlock(fontChar, cols, rows, LINE_HEIGHT);
    loader = new BrailleNoise(4, 1, 0.1, GREEN);

    // TODO: design a warning graphic/pattern for failed calendar fetches. Today the screen
    // can't tell: if one feed fails at startup it shows only the other feed's events (even
    // "NO MORE EVENTS TODAY"), and after a long outage it shows old events as current.
    // Needs per-feed status (never loaded / last success time) from DataCalendarIcs.

    // A snapshot: rows don't jump around mid-animation if new data arrives
    DataCalendar calendar = store.calendar();
    if (calendar == null) {
      loading = true;
      return;
    }
    LocalDateTime now = LocalDateTime.now();
    timelineEvents = calendar.today(now);
    lanes = timelineLanes(timelineEvents);
    java.util.List<DataCalendar.Event> events = calendar.remainingToday(now);

    // As many entries as fit, leaving one row for END / +N MORE.
    // Each entry takes its 2 rows plus 1 (empty or overlap) below it.
    int row = FIRST_ROW;
    for (DataCalendar.Event event : events) {
      if (row + CalendarEntry.HEIGHT + 1 >= rows) break;
      entries.add(new CalendarEntry(cols - 2, event, entries.isEmpty()));
      row += CalendarEntry.HEIGHT + 1;
    }
    hiddenCount = events.size() - entries.size();
  }

  void drawIntro() {
    writeBlock();
    reveal.apply(block, tl.t());
    drawScreen();
    if (reveal.isDone()) nextPhase();
  }

  void drawMain() {
    writeBlock();
    drawScreen();
    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    writeBlock();
    hide.apply(block, 1 - tl.progress(0, OUTRO_LENGTH));
    drawScreen();
    if (tl.t() >= OUTRO_LENGTH) nextPhase();
  }

  /**
   * All components write their Cells. Entries stack with an empty row between them,
   * or an overlap row when an event is still on when the next one starts.
   */
  void writeBlock() {
    block.clear();
    // "─┄ TODAY◢ 22.10.2026 ┄┄──────…" across the whole row
    int headerEnd = block.put(0, 0, "─┄ TODAY◢ " + date + " ┄┄", GREEN);
    block.putRepeated(headerEnd, 0, block.cols - headerEnd, '─', GREEN);

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
      if (overlapsNext) {
        // "🮙🮙🮙 OVERLAP 🮙🮙🮙" in red
        int col = block.put(5, row, "🮙🮙🮙", RED);
        col = block.putInverted(col, row, " OVERLAP ", RED);
        block.put(col, row, "🮙🮙🮙", RED);
      }
      row += 1;
    }

    if (entries.isEmpty()) {
      int col = block.put(5, row, "░   ", GREEN);
      block.putInverted(col, row, " NO MORE EVENTS TODAY ", GREEN);
      row += 2;
    }
    block.put(5, row, hiddenCount > 0 ? "░   +" + hiddenCount + " MORE" : "░   END", GREEN);
  }

  void drawScreen() {
    background(BACKGROUND);
    drawTimeline();
    block.draw(MARGIN, BLOCK_TOP);
  }

  /**
   * Today's events as bars on the 08:00–18:00 grid, and a marker at the current time.
   * Ended events are gray. Where two events that haven't ended overlap, both bars are red.
   */
  void drawTimeline() {
    LocalDateTime now = LocalDateTime.now();
    noStroke();

    // A tick every half hour: dotted on half hours, solid on hours, long every 4 hours.
    // 1 px rects instead of lines, so they stay sharp.
    fill(GREEN);
    float tickTop = TIMELINE_TOP + 28;
    for (int i = 0; i <= (TIMELINE_LAST_HOUR - TIMELINE_FIRST_HOUR) * 2; i++) {
      float x = TIMELINE_LEFT + i * HOUR_WIDTH / 2;
      if (i % 8 == 0) {
        rect(x, tickTop, 1, 24);
      } else if (i % 2 == 0) {
        rect(x, tickTop, 1, 8);
      } else {
        for (int dot = 1; dot < 8; dot += 3) rect(x, tickTop + dot, 1, 1);
      }
    }

    for (int i = 0; i < timelineEvents.size(); i++) {
      DataCalendar.Event event = timelineEvents.get(i);
      drawBar(event, lanes[i], event.start, event.end, hasEnded(event, now) ? GRAY : GREEN);
    }

    // Overlaps in red on both bars. Events are sorted by start, so only later events
    // can overlap an event. An overlap is over once either event has ended: it stays gray.
    for (int i = 0; i < timelineEvents.size(); i++) {
      DataCalendar.Event a = timelineEvents.get(i);
      for (int j = i + 1; j < timelineEvents.size() && timelineEvents.get(j).start.isBefore(a.end); j++) {
        DataCalendar.Event b = timelineEvents.get(j);
        if (hasEnded(a, now) || hasEnded(b, now)) continue;
        LocalDateTime overlapEnd = a.end.isBefore(b.end) ? a.end : b.end;
        drawBar(a, lanes[i], b.start, overlapEnd, RED);
        drawBar(b, lanes[j], b.start, overlapEnd, RED);
      }
    }

    // Now: a 2 px line, and on top of it a pill with a 2 px yellow outline
    float nowX = timeToX(now);
    fill(YELLOW);
    rect(nowX - 1, TIMELINE_TOP + 12, 2, 44);
    rect(nowX - 5, TIMELINE_TOP, 10, 24, 5);
    fill(BACKGROUND);
    rect(nowX - 3, TIMELINE_TOP + 2, 6, 20, 3);
  }

  /** The part from–to of an event's bar. Where it reaches the event's own start or end, it's rounded. */
  void drawBar(DataCalendar.Event event, int lane, LocalDateTime from, LocalDateTime to, color c) {
    float left = timeToX(from);
    float leftRadius = from.equals(event.start) ? BAR_HEIGHT / 2 : 0;
    float rightRadius = to.equals(event.end) ? BAR_HEIGHT / 2 : 0;
    fill(c);
    rect(left, TIMELINE_TOP + 44 + lane * LANE_STEP, timeToX(to) - left, BAR_HEIGHT,
      leftRadius, rightRadius, rightRadius, leftRadius);
  }

  /** Not clamped: times outside the grid land past its ends. */
  float timeToX(LocalDateTime time) {
    float hours = java.time.Duration.between(timelineStart, time).getSeconds() / 3600.0;
    return TIMELINE_LEFT + hours * HOUR_WIDTH;
  }

  boolean hasEnded(DataCalendar.Event event, LocalDateTime now) {
    return !event.end.isAfter(now);
  }
}

/**
 * Timeline lane for each event (sorted by start): the first lane that is free when the
 * event starts. Usually all are in lane 0; overlapping events stack into lanes below.
 */
int[] timelineLanes(java.util.List<DataCalendar.Event> events) {
  int[] lanes = new int[events.size()];
  ArrayList<LocalDateTime> laneEnds = new ArrayList<LocalDateTime>();   // when each lane is free again
  for (int i = 0; i < events.size(); i++) {
    DataCalendar.Event event = events.get(i);
    int lane = 0;
    while (lane < laneEnds.size() && laneEnds.get(lane).isAfter(event.start)) lane++;
    if (lane == laneEnds.size()) laneEnds.add(event.end);
    else laneEnds.set(lane, event.end);
    lanes[i] = lane;
  }
  return lanes;
}

/** Runs at startup when debug is on. */
void calendarSelfCheck() {
  // 09:00–10:00, 09:30–10:30, 10:00–11:00 (lane 0 is free again at 10:00),
  // 10:15–10:45 (lanes 0 and 1 busy: a third lane)
  LocalDateTime day = LocalDateTime.of(2026, 3, 28, 0, 0);
  int[][] minutes = { {540, 600}, {570, 630}, {600, 660}, {615, 645} };
  java.util.List<DataCalendar.Event> events = new ArrayList<DataCalendar.Event>();
  for (int[] m : minutes) {
    events.add(new DataCalendar.Event("", day.plusMinutes(m[0]), day.plusMinutes(m[1]), false, false));
  }
  selfCheck(java.util.Arrays.equals(timelineLanes(events), new int[] {0, 1, 0, 2}), "timeline lanes");
  println("[calendar] self-check ok");
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
