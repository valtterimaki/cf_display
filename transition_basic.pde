// Placeholder transition: a CRT-style line.
// A thin bright line opens across the black screen and collapses to a dot.

class TransitionBasic extends CoreTransition {

  final float LENGTH = 0.6;

  void drawTransition() {
    background(0);

    float open = CoreEase.outCubic(tl.progress(0, 0.25));
    float close = CoreEase.inCubic(tl.progress(0.3, 0.25));
    float lineWidth = width * open * (1 - close);

    if (lineWidth > 1) {
      noStroke();
      fill(220, 235, 255);
      rectMode(CENTER);
      rect(width / 2, height / 2, lineWidth, 3);
      rectMode(CORNER);
    }

    if (tl.t() >= LENGTH) finish();
  }
}
