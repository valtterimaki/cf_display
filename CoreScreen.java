/**
 * Base class for all screens.
 *
 * Every screen goes through the same phases:
 *
 *   INTRO  →  MAIN  →  OUTRO  →  DONE
 *
 * The screen itself decides when each phase ends by calling nextPhase().
 * The scheduler only starts screens and waits for them to reach DONE.
 *
 * Screens are written in screen_*.pde files so they can draw directly:
 *
 *   class ScreenExample extends CoreScreen {
 *     void start()     { ... }  // optional: reset things when the screen appears
 *     void drawIntro() { ...; if (tl.t() > 1.0) nextPhase(); }
 *     void drawMain()  { ...; if (tl.t() > 8.0) nextPhase(); }
 *     void drawOutro() { ...; if (tl.t() > 0.8) nextPhase(); }
 *   }
 *
 * `tl` is a CoreTimeline that restarts at zero at the start of every phase.
 *
 * Note: the methods screens implement have no access modifier (not public).
 * That way .pde files can write plain `void drawMain()` like normal Processing code.
 */
public abstract class CoreScreen {

  public enum Phase { INTRO, MAIN, OUTRO, DONE }

  /** Timeline for the current phase. Restarts at 0 on every phase change. */
  protected CoreTimeline tl = new CoreTimeline(0);

  private Phase phase = Phase.DONE;
  private boolean outroRequested = false;
  private float now = 0;

  // --- implemented by each screen ---

  /** Called when the screen is shown. Reset animation state here. Optional. */
  void start() {}

  abstract void drawIntro();
  abstract void drawMain();
  abstract void drawOutro();

  /**
   * React to input that isn't handled globally (e.g. knob turns). Optional.
   * SKIP, SHOW_SCREEN and TOGGLE_DEBUG are handled by the main sketch, not here.
   */
  void onAction(HwAction action) {}

  /**
   * Return true to keep the same instance between showings (state is kept).
   * Default false: a fresh instance is created every time the screen is shown.
   */
  boolean keepsState() {
    return false;
  }

  // --- used by screens ---

  /** Move to the next phase. INTRO → MAIN → OUTRO → DONE. */
  protected void nextPhase() {
    switch (phase) {
      case INTRO: setPhase(outroRequested ? Phase.OUTRO : Phase.MAIN); break;
      case MAIN:  setPhase(Phase.OUTRO); break;
      case OUTRO: setPhase(Phase.DONE); break;
      case DONE:  break;
    }
  }

  /** True if the scheduler has asked this screen to wrap up early (e.g. SKIP). */
  protected boolean isOutroRequested() {
    return outroRequested;
  }

  public Phase phase() {
    return phase;
  }

  // --- used by the scheduler ---

  /** Show the screen from the beginning. */
  public void begin(float now) {
    this.now = now;
    outroRequested = false;
    setPhase(Phase.INTRO);
    start();
  }

  /**
   * Ask the screen to wrap up early.
   * During MAIN it goes straight to OUTRO.
   * During INTRO the intro finishes first, then it skips MAIN.
   */
  public void requestOutro() {
    if (phase == Phase.INTRO) outroRequested = true;
    if (phase == Phase.MAIN) setPhase(Phase.OUTRO);
  }

  /** Advance time and draw the current phase. Call once per frame. */
  public void update(float now) {
    this.now = now;
    tl.update(now);
    switch (phase) {
      case INTRO: drawIntro(); break;
      case MAIN:  drawMain();  break;
      case OUTRO: drawOutro(); break;
      case DONE:  break;
    }
  }

  public boolean isDone() {
    return phase == Phase.DONE;
  }

  // --- internals ---

  private void setPhase(Phase next) {
    phase = next;
    tl.restart(now);
    System.out.println("[screen] " + getClass().getSimpleName() + " -> " + next);
  }
}
