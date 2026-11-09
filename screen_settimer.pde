// Set timer: opened with the timer button. The knob sets the time; the timer starts
// 3 s after the last turn (CoreTimer). The timer button closes the screen, and so does
// 15 s without input. Placeholder look until designed.

class ScreenSetTimer extends CoreScreen {

  final float TIMEOUT = 15;   // seconds since the last input

  float lastInput;

  void start() {
    lastInput = now();
  }

  void drawIntro() {
    nextPhase();
  }

  void drawMain() {
    background(BACKGROUND);
    noStroke();
    textAlign(CENTER, CENTER);
    fill(WHITE);
    textFont(fontTitle);
    text("Set timer", width / 2, 140);
    textFont(fontHuge);
    text(fmtTimer(timer.remaining(now()), true), width / 2, height / 2);

    fill(GRAY);
    textFont(fontBody);
    text(stateText(), width / 2, height / 2 + 100);
    textFont(fontSmall);
    text("numbers + graphic (placeholder)", width / 2, height - 40);

    if (now() - lastInput >= TIMEOUT) nextPhase();
  }

  void drawOutro() {
    nextPhase();
  }

  void onAction(HwAction action) {
    lastInput = now();
    if (action.type == HwAction.Type.ENCODER_TURN) timer.turn(action.value, now());
    if (action.type == HwAction.Type.TIMER_BUTTON) {
      timer.startNow(now());
      requestOutro();
    }
  }

  String stateText() {
    switch (timer.state()) {
      case ADJUSTING: return "starts when you stop turning";
      case RUNNING:   return "running";
      default:        return "turn the knob";
    }
  }
}
