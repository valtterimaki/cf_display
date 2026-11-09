// Home: analog clock with a timer widget, shown between visits (Figma "Home clock").
// After 3 minutes it's done and a visit starts (see CoreTriggers.planVisit).
//
// Timer widget, only while the timer runs: a yellow arc from a hand to the time the
// timer ends (it shrinks toward the hand), and the countdown at bottom right.
// Over an hour left it's on the hour scale from the hour hand, under an hour on the
// minute scale from the minute hand. A missed alarm shows nothing yet (PLAN.md §5).
//
// Intro and outro not designed yet. The drawing is split into parts (dial, hands,
// timer, time) so they can be animated separately later.

class ScreenHome extends CoreScreen {

  final float MAIN_LENGTH = 180;

  // Distances from the center, from the Figma frame (720 × 720, center 360, 360).
  // Lines have round caps, so each end is half the line width in from the Figma edge.
  final float LINE_WIDTH = 4;
  final float TIC_FROM = 258, TIC_TO = 270;
  final float HOUR_FROM = 41, HOUR_TO = 158;     // two lines, 12 px apart
  final float MINUTE_FROM = -38, MINUTE_TO = 246; // negative: a short tail behind the center
  final float SECOND_FROM = 226, SECOND_TO = 246; // two short marks, 12 px apart
  final float PAIR_GAP = 12;
  final float ARC_DIAMETER = 503;   // inner edge at 250, outer at 253
  final float ARC_WIDTH = 3;

  final float TEXT_MARGIN_LEFT = 24, TEXT_MARGIN_RIGHT = 32;
  final float TEXT_BASELINE = 681;

  void drawIntro() {
    nextPhase();
  }

  void drawMain() {
    background(BACKGROUND);
    LocalDateTime time = CoreClock.now();

    pushMatrix();
    translate(width / 2, height / 2);
    drawDial();
    drawHands(time);
    drawTimerArc(time);
    popMatrix();

    drawTime(time);
    drawCountdown();

    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    nextPhase();
  }

  // --- parts (drawn around the center, except the texts) ---

  void drawDial() {
    stroke(CLOCK_TIC);
    strokeWeight(LINE_WIDTH);
    strokeCap(ROUND);
    for (int i = 0; i < 12; i++) {
      drawRadial(i * TWO_PI / 12, 0, TIC_FROM, TIC_TO);
    }
  }

  void drawHands(LocalDateTime time) {
    strokeWeight(LINE_WIDTH);
    strokeCap(ROUND);

    stroke(CLOCK_SECOND);
    float second = secondAngle(time.getSecond(), time.getNano() / 1e9);
    drawRadial(second, -PAIR_GAP / 2, SECOND_FROM, SECOND_TO);
    drawRadial(second, PAIR_GAP / 2, SECOND_FROM, SECOND_TO);

    stroke(WHITE);
    drawRadial(minuteAngle(time), 0, MINUTE_FROM, MINUTE_TO);

    float hour = hourAngle(time);
    drawRadial(hour, -PAIR_GAP / 2, HOUR_FROM, HOUR_TO);
    drawRadial(hour, PAIR_GAP / 2, HOUR_FROM, HOUR_TO);
  }

  void drawTimerArc(LocalDateTime time) {
    if (timer.state() != CoreTimer.State.RUNNING) return;
    // The hands show the last whole second: measure the remaining time from there too,
    // or the arc's end would creep back during a second and jump when the hand moves.
    float remaining = timer.remaining(now()) + time.getNano() / 1e9;
    float start = remaining < 3600 ? minuteAngle(time) : hourAngle(time);
    float end = start + timerSweep(remaining);
    if (end - start < 0.001) return;   // P2D prints an error for a zero-sweep arc

    noFill();
    stroke(CLOCK_TIMER);
    strokeWeight(ARC_WIDTH);
    strokeCap(SQUARE);
    // arc() counts from 3 o'clock, clock angles from 12
    arc(0, 0, ARC_DIAMETER, ARC_DIAMETER, start - HALF_PI, end - HALF_PI);
  }

  void drawTime(LocalDateTime time) {
    noStroke();
    fill(WHITE);
    textFont(fontHomeTime);
    textAlign(LEFT, BASELINE);
    text(fmtTime(time), TEXT_MARGIN_LEFT, TEXT_BASELINE);
  }

  void drawCountdown() {
    if (timer.state() != CoreTimer.State.RUNNING) return;
    noStroke();
    fill(CLOCK_TIMER);
    textFont(fontHomeTimer);
    textAlign(RIGHT, BASELINE);
    text(fmtCountdown(timer.remaining(now())), width - TEXT_MARGIN_RIGHT, TEXT_BASELINE);
  }

  /** A line along a clock angle, from one distance to another, shifted sideways by x. */
  void drawRadial(float angle, float x, float from, float to) {
    pushMatrix();
    rotate(angle);
    line(x, -from, x, -to);
    popMatrix();
  }
}

// Clock angles: radians clockwise from 12 o'clock. Plain functions so the self-check can use them.

// Second hand: jumps at each full second, overshoots a little and settles
final float SECOND_TICK_LENGTH = 0.15;   // seconds

// Hour and minute hands (and the timer arc's start) move once per second.
float hourAngle(LocalDateTime time) {
  return (time.getHour() % 12 + minutes(time) / 60) * TWO_PI / 12;
}

float minuteAngle(LocalDateTime time) {
  return minutes(time) * TWO_PI / 60;
}

/** Minutes into the hour, in whole seconds. */
float minutes(LocalDateTime time) {
  return time.getMinute() + time.getSecond() / 60.0;
}

/** Stays on the previous second until the tick, then jumps there with a small overshoot. */
float secondAngle(int second, float fraction) {
  float tick = CoreEase.outBack(min(fraction / SECOND_TICK_LENGTH, 1));
  return (second - 1 + tick) * TWO_PI / 60;
}

/** How far the timer arc reaches: under an hour on the minute scale, else on the hour scale. */
float timerSweep(float remainingSeconds) {
  float hours = remainingSeconds / 3600;
  return hours < 1 ? hours * TWO_PI : hours * TWO_PI / 12;
}

/** Runs at startup when debug is on. */
void homeSelfCheck() {
  LocalDateTime t = LocalDateTime.of(2026, 11, 9, 13, 27, 0);
  selfCheck(abs(degrees(hourAngle(t)) - 43.5) < 0.01, "hour hand at 13:27");
  selfCheck(abs(degrees(minuteAngle(t)) - 162) < 0.01, "minute hand at 13:27");
  selfCheck(abs(degrees(secondAngle(17, 0)) - 96) < 0.01, "second hand waits for the tick");
  selfCheck(abs(degrees(secondAngle(17, 0.5)) - 102) < 0.01, "second hand settled after the tick");
  selfCheck(abs(degrees(secondAngle(0, 0.5))) < 0.01, "second hand at 12");
  selfCheck(abs(degrees(timerSweep(2 * 3600 + 13 * 60 + 27)) - 66.7) < 0.1, "2:13'27 left on the hour scale");
  selfCheck(abs(degrees(timerSweep(13 * 60 + 27)) - 80.7) < 0.1, "13'27 left on the minute scale");
  println("[home] self-check ok");
}
