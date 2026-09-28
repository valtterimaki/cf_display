// Example screen for learning how screens, timelines and eases work together.
// Intro: two rounded bars grow from zero width; halfway through, bar B slides down.
// Main: the bars stay still. Outro: the same thing in reverse.
//
// Lifetime of a screen (the scheduler drives all of this, see CoreScheduler.java):
//   1. The scheduler creates a fresh ScreenExample and calls start().
//   2. Every frame it calls drawIntro(), drawMain() or drawOutro(),
//      depending on which phase the screen is in.
//   3. The screen calls nextPhase() when the current phase is finished:
//      INTRO → MAIN → OUTRO → DONE
//   4. At DONE the scheduler plays the transition, then starts the next screen.
//   Pressing SKIP (space) makes MAIN end early and jump straight to OUTRO.

class ScreenExample extends CoreScreen {

  // --- timing, in seconds ---

  final float GROW_LENGTH = 1.0;                       // bars grow from 0 to full width in this time
  final float MOVE_START = GROW_LENGTH / 2;            // bar B starts moving halfway through the grow
  final float MOVE_LENGTH = 0.8;                       // bar B moves for this long
  final float INTRO_LENGTH = MOVE_START + MOVE_LENGTH; // intro is over when the move is over

  final float MAIN_LENGTH = 5.0;                       // bars stay still this long (unless SKIP)

  final float SHRINK_START = MOVE_LENGTH / 2;          // outro: bars start shrinking halfway through the move back
  final float OUTRO_LENGTH = SHRINK_START + GROW_LENGTH;

  // --- layout, in pixels ---

  final float BAR_X = 160;          // left edge of both bars (bars grow to the right)
  final float BAR_WIDTH = 400;      // full width
  final float BAR_HEIGHT = 80;
  final float CORNER_RADIUS = 20;
  final float A_Y = 240;            // bar A never moves
  final float B_START_Y = 330;      // bar B starts just below bar A...
  final float B_END_Y = 430;        // ...and slides down to here

  // --- lifetime ---

  void start() {
    // Called once when the scheduler shows this screen, before the first drawIntro().
    // The screen is a fresh instance every time, so there is nothing to reset.
    // In a real screen this is where you would copy data from `store`.
    println("[example] start");
  }

  // --- phases ---

  void drawIntro() {
    // Clear the frame. Every frame is drawn from scratch.
    background(20, 24, 32);

    // tl.t() = seconds since this phase started.
    // tl.progress(start, length) turns that into 0..1 over a time window:
    // 0 before `start`, rising to 1 at `start + length`, staying 1 after that.
    float grow = tl.progress(0, GROW_LENGTH);

    // An ease reshapes the 0..1 value. outCubic starts fast and slows down at the end.
    // The value is still 0 at the start and 1 at the end.
    grow = CoreEase.outCubic(grow);

    // Same for the move, but it only starts at MOVE_START. Before that it stays 0.
    float move = CoreEase.outCubic(tl.progress(MOVE_START, MOVE_LENGTH));

    // Turn the 0..1 values into pixels.
    // lerp(a, b, x) gives a when x = 0, b when x = 1, and values between for everything else.
    float barWidth = lerp(0, BAR_WIDTH, grow);
    float barBY = lerp(B_START_Y, B_END_Y, move);

    drawBars(barWidth, barBY);

    // tl.once(time) is true on exactly one frame: the one where time passes that mark.
    // Handy for one-off events like playing a sound or logging.
    if (tl.once(MOVE_START)) println("[example] bar B starts moving");

    // The screen decides when the intro is over. Next phase is MAIN
    // (or OUTRO directly, if SKIP was pressed during the intro).
    if (tl.t() >= INTRO_LENGTH) nextPhase();
  }

  void drawMain() {
    background(20, 24, 32);

    // Nothing moves here: draw the bars at their final size and position.
    // tl.t() started again from 0 when this phase began.
    drawBars(BAR_WIDTH, B_END_Y);

    // Move on to OUTRO after a while. Without this line the screen would stay
    // until SKIP is pressed, and no other screen would ever get a turn.
    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    background(20, 24, 32);

    // The intro in reverse: first bar B moves back up...
    // inCubic starts slow and speeds up, the mirror of the intro's outCubic.
    float moveBack = CoreEase.inCubic(tl.progress(0, MOVE_LENGTH));

    // ...and halfway through that move, both bars start shrinking.
    float shrink = CoreEase.inCubic(tl.progress(SHRINK_START, GROW_LENGTH));

    // Note the swapped lerp ends: we go from the end values back to the start values.
    float barWidth = lerp(BAR_WIDTH, 0, shrink);
    float barBY = lerp(B_END_Y, B_START_Y, moveBack);

    drawBars(barWidth, barBY);

    // When the outro is over, nextPhase() goes to DONE. The scheduler notices
    // that on this same frame and starts the transition to the next screen.
    if (tl.t() >= OUTRO_LENGTH) nextPhase();
  }

  // --- drawing ---

  void drawBars(float barWidth, float barBY) {
    // Zero width: nothing to draw, so skip it.
    if (barWidth < 1) return;

    // Processing keeps style settings (fill, rectMode, ...) between frames and
    // between screens, so set everything this drawing depends on.
    rectMode(CORNER);   // x, y = top-left corner
    noStroke();

    // Bar A: orange, fixed position.
    // The 5th argument of rect() is the corner radius. Processing limits it to
    // half the width, so a very narrow bar becomes a thin pill shape.
    fill(240, 120, 80);
    rect(BAR_X, A_Y, barWidth, BAR_HEIGHT, CORNER_RADIUS);

    // Bar B: blue, same width, its own y position.
    fill(90, 170, 240);
    rect(BAR_X, barBY, barWidth, BAR_HEIGHT, CORNER_RADIUS);
  }
}
