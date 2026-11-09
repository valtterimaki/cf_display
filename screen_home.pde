// Home: the clock and widgets, shown between visits. Placeholder until designed.
// After 3 minutes it's done and a visit starts (see CoreTriggers.planVisit).

class ScreenHome extends CoreScreen {

  final float MAIN_LENGTH = 180;

  void drawIntro() {
    nextPhase();
  }

  void drawMain() {
    background(BACKGROUND);
    noStroke();
    textAlign(CENTER, CENTER);
    fill(WHITE);
    textFont(fontHuge);
    text(fmtTime(CoreClock.now()), width / 2, height / 2 - 40);

    fill(YELLOW);
    textFont(fontBody);
    text(timerWidgetText(), width / 2, height / 2 + 60);

    fill(GRAY);
    textFont(fontSmall);
    text("home: clock + widgets (placeholder)", width / 2, height - 40);

    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    nextPhase();
  }

  String timerWidgetText() {
    if (timer.state() == CoreTimer.State.RUNNING) return "timer " + fmtTimer(timer.remaining(now()), false);
    if (timer.isMissed()) return "timer finished " + floor(timer.sinceRang(now()) / 60) + " min ago";
    return "";
  }
}
