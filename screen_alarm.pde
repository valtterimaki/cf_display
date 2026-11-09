// Timer alarm: interrupts any screen when the timer reaches zero, or comes right after
// the welcome if it went off during sleep (then it shows how long ago).
// Any input clears it (handleActions). Unanswered after a minute, home shows a note.

class ScreenAlarm extends CoreScreen {

  final float MAIN_LENGTH = 60;
  final float LATE_AFTER = 5;   // show "went off ... ago" when shown later than this

  void drawIntro() {
    nextPhase();
  }

  void drawMain() {
    float late = timer.sinceRang(now());
    String note = late > LATE_AFTER ? "went off " + fmtTimer(late, false) + " ago" : "any button clears";
    drawPlaceholder("Timer alarm", note);

    if (tl.t() >= MAIN_LENGTH) {
      timer.alarmUnanswered();
      nextPhase();
    }
  }

  void drawOutro() {
    nextPhase();
  }
}
