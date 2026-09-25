// Placeholder screen: calendar.
// No real data yet (comes in step 6). Intro: event rows slide in one by one.
// Outro: rows slide out one by one.

class ScreenCalendar extends CoreScreen {

  final float MAIN_LENGTH = 6.0;

  final int ROWS = 4;
  final float ROW_DELAY = 0.12;     // stagger between rows
  final float ROW_SLIDE = 0.5;      // slide duration per row
  final float ROW_HEIGHT = 90;
  final float TOP = 200;

  int selectedRow = 0;   // moved with the knob (mouse wheel / , . in simulation)

  void onAction(HwAction action) {
    if (action.type == HwAction.Type.ENCODER_TURN) {
      selectedRow = constrain(selectedRow + action.value, 0, ROWS - 1);
    }
  }

  void drawIntro() {
    background(28, 26, 36);
    drawTitle(255 * tl.progress(0, 0.4));
    for (int i = 0; i < ROWS; i++) {
      float p = CoreEase.outCubic(tl.progress(i * ROW_DELAY, ROW_SLIDE));
      drawRow(i, lerp(-width, 0, p));
    }

    if (tl.t() >= (ROWS - 1) * ROW_DELAY + ROW_SLIDE) nextPhase();
  }

  void drawMain() {
    background(28, 26, 36);
    drawTitle(255);
    for (int i = 0; i < ROWS; i++) drawRow(i, 0);

    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    background(28, 26, 36);
    drawTitle(255 * (1 - tl.progress(0, 0.3)));
    for (int i = 0; i < ROWS; i++) {
      float p = CoreEase.inCubic(tl.progress(i * ROW_DELAY, ROW_SLIDE));
      drawRow(i, lerp(0, width, p));
    }

    if (tl.t() >= (ROWS - 1) * ROW_DELAY + ROW_SLIDE) nextPhase();
  }

  void drawTitle(float alpha) {
    fill(240, alpha);
    textAlign(LEFT, CENTER);
    textSize(40);
    text("CALENDAR (placeholder)", 80, 120);
  }

  void drawRow(int i, float offsetX) {
    float y = TOP + i * ROW_HEIGHT;
    noStroke();
    if (i == selectedRow) fill(120, 100, 190);
    else fill(70, 60, 110);
    rect(80 + offsetX, y, 560, ROW_HEIGHT - 20, 8);
    fill(240);
    textAlign(LEFT, CENTER);
    textSize(24);
    text("--:--   Event " + (i + 1), 104 + offsetX, y + (ROW_HEIGHT - 20) / 2);
  }
}
