// Sleep: a black screen until presence or a button wakes the device (CoreTriggers).

class ScreenSleep extends CoreScreen {

  void drawIntro() {
    nextPhase();
  }

  void drawMain() {
    background(BACKGROUND);
  }

  void drawOutro() {
    nextPhase();
  }
}
