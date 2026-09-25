// Placeholder screen: a clock.
// Intro: ring draws itself, time slides in. Main: ticking clock. Outro: everything collapses.

class ScreenClock extends CoreScreen {

  final float INTRO_LENGTH = 1.4;
  final float MAIN_LENGTH = 6.0;
  final float OUTRO_LENGTH = 0.8;

  final float RING_SIZE = 460;

  void drawIntro() {
    background(20, 24, 32);

    // Ring draws itself around the circle
    float ring = CoreEase.inOutCubic(tl.progress(0, 1.0));
    drawRing(RING_SIZE, ring * TWO_PI, 255);

    // Time slides up and fades in, starting a bit later
    float text = CoreEase.outBack(tl.progress(0.5, 0.9));
    drawTime(lerp(40, 0, text), text * 255);

    if (tl.t() >= INTRO_LENGTH) nextPhase();
  }

  void drawMain() {
    background(20, 24, 32);
    drawRing(RING_SIZE, TWO_PI, 255);
    drawSecondsDot();
    drawTime(0, 255);

    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    background(20, 24, 32);

    // Ring shrinks to nothing, time fades out quickly
    float shrink = CoreEase.inCubic(tl.progress(0, OUTRO_LENGTH));
    drawRing(RING_SIZE * (1 - shrink), TWO_PI, 255 * (1 - shrink));
    drawTime(0, 255 * (1 - tl.progress(0, 0.3)));

    if (tl.t() >= OUTRO_LENGTH) nextPhase();
  }

  // --- drawing pieces ---

  void drawRing(float size, float angle, float alpha) {
    // P2D can't tessellate an empty arc, so skip zero size / zero sweep
    if (size < 1 || angle < 0.01) return;
    noFill();
    stroke(240, alpha);
    strokeWeight(6);
    arc(width / 2, height / 2, size, size, -HALF_PI, -HALF_PI + angle);
  }

  void drawSecondsDot() {
    float a = -HALF_PI + TWO_PI * second() / 60.0;
    float r = RING_SIZE / 2;
    noStroke();
    fill(240, 120, 80);
    ellipse(width / 2 + cos(a) * r, height / 2 + sin(a) * r, 18, 18);
  }

  void drawTime(float offsetY, float alpha) {
    fill(240, alpha);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(96);
    text(nf(hour(), 2) + ":" + nf(minute(), 2), width / 2, height / 2 + offsetY);
  }
}
