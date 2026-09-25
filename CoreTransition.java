/**
 * Base class for animations played between two screens.
 *
 * Written in transition_*.pde files so they can draw directly:
 *
 *   class TransitionExample extends CoreTransition {
 *     void drawTransition() { ...; if (tl.t() > 0.6) finish(); }
 *   }
 *
 * The screen is NOT cleared before a transition — the last frame of the
 * previous screen's outro is still there, and the transition can use it.
 * `fromId` and `toId` tell which screens it is between, if it cares.
 */
public abstract class CoreTransition {

  /** Timeline that starts at 0 when the transition begins. */
  protected CoreTimeline tl = new CoreTimeline(0);

  protected String fromId;
  protected String toId;

  private boolean done = true;

  // --- implemented by each transition ---

  abstract void drawTransition();

  // --- used by transitions ---

  /** Call when the transition is finished. */
  protected void finish() {
    done = true;
  }

  // --- used by the scheduler ---

  public void begin(float now, String fromId, String toId) {
    this.fromId = fromId;
    this.toId = toId;
    done = false;
    tl.restart(now);
  }

  public void update(float now) {
    tl.update(now);
    drawTransition();
  }

  public boolean isDone() {
    return done;
  }
}
