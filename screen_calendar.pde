// Placeholder screen: calendar.
// Shows upcoming events from the data store. Intro: rows slide in one by one.
// Outro: rows slide out one by one. The knob moves the highlighted row.

class ScreenCalendar extends CoreScreen {

  final float MAIN_LENGTH = 6.0;

  final int MAX_ROWS = 4;
  final float ROW_DELAY = 0.12;     // stagger between rows
  final float ROW_SLIDE = 0.5;      // slide duration per row
  final float ROW_HEIGHT = 90;
  final float TOP = 200;

  java.util.List<DataCalendar.Event> events = new java.util.ArrayList<DataCalendar.Event>();
  int selectedRow = 0;   // moved with the knob (mouse wheel / , . in simulation)

  void start() {
    // Take a snapshot of the events when the screen appears,
    // so rows don't jump around mid-animation if new data arrives.
    DataCalendar calendar = store.calendar();
    if (calendar != null) events = calendar.upcoming(LocalDateTime.now(), MAX_ROWS);
  }

  void onAction(HwAction action) {
    if (action.type == HwAction.Type.ENCODER_TURN && events.size() > 0) {
      selectedRow = constrain(selectedRow + action.value, 0, events.size() - 1);
    }
  }

  void drawIntro() {
    background(28, 26, 36);
    drawTitle(255 * tl.progress(0, 0.4));
    for (int i = 0; i < events.size(); i++) {
      float p = CoreEase.outCubic(tl.progress(i * ROW_DELAY, ROW_SLIDE));
      drawRow(i, lerp(-width, 0, p));
    }

    if (tl.t() >= rowsAnimationLength()) nextPhase();
  }

  void drawMain() {
    background(28, 26, 36);
    drawTitle(255);
    for (int i = 0; i < events.size(); i++) drawRow(i, 0);
    if (events.isEmpty()) drawEmpty();

    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    background(28, 26, 36);
    drawTitle(255 * (1 - tl.progress(0, 0.3)));
    for (int i = 0; i < events.size(); i++) {
      float p = CoreEase.inCubic(tl.progress(i * ROW_DELAY, ROW_SLIDE));
      drawRow(i, lerp(0, width, p));
    }

    if (tl.t() >= rowsAnimationLength()) nextPhase();
  }

  float rowsAnimationLength() {
    return max(0, events.size() - 1) * ROW_DELAY + ROW_SLIDE;
  }

  void drawTitle(float alpha) {
    fill(240, alpha);
    textAlign(LEFT, CENTER);
    textFont(fontTitle);
    text("CALENDAR", 80, 120);
  }

  void drawEmpty() {
    fill(160);
    textAlign(LEFT, CENTER);
    textFont(fontBody);
    text("No upcoming events", 80, TOP + 35);
  }

  void drawRow(int i, float offsetX) {
    DataCalendar.Event event = events.get(i);
    float y = TOP + i * ROW_HEIGHT;
    float h = ROW_HEIGHT - 20;

    noStroke();
    if (i == selectedRow) fill(120, 100, 190);
    else fill(70, 60, 110);
    rect(80 + offsetX, y, 560, h, 8);

    fill(240);
    textFont(fontBody);
    textAlign(LEFT, CENTER);
    text(fmtTime(event.start) + "   " + event.title, 104 + offsetX, y + h / 2);
    textAlign(RIGHT, CENTER);
    fill(200);
    textFont(fontSmall);
    text(fmtTimeUntil(event.start), 616 + offsetX, y + h / 2);
  }
}
