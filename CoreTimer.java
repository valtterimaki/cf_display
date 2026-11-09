/**
 * The countdown timer set with the knob.
 *
 *   IDLE       nothing set
 *   ADJUSTING  knob being turned; starts running 3 s after the last turn
 *   RUNNING    counting down
 *   RINGING    reached zero, waiting for the alarm to be cleared
 *
 * Turning the knob while running pauses it and adjusts the remaining time.
 * Turning it down to zero resets it.
 */
public class CoreTimer {

  public enum State { IDLE, ADJUSTING, RUNNING, RINGING }

  public static final float START_DELAY = 3;
  public static final float MAX = 10 * 3600;

  private State state = State.IDLE;
  private float remaining = 0;     // while IDLE or ADJUSTING
  private float endsAt = 0;        // while RUNNING, in sketch time
  private float lastTurn = 0;
  private float rangAt = 0;        // when it reached zero
  private boolean missed = false;  // alarm went unanswered; home shows it until a button press

  /** Knob turned by some steps (negative = down). */
  public void turn(int steps, float now) {
    float value = remaining(now);
    for (int i = 0; i < Math.abs(steps); i++) {
      value = steps > 0 ? stepUp(value) : stepDown(value);
    }
    remaining = value;
    lastTurn = now;
    state = value > 0 ? State.ADJUSTING : State.IDLE;
    System.out.println("[timer] set " + Math.round(value) + " s");
  }

  /** Start right away instead of waiting for the delay (leaving the set timer screen). */
  public void startNow(float now) {
    if (state == State.ADJUSTING) run(now);
  }

  /** Call once per frame. Returns true on the frame the timer reaches zero. */
  public boolean update(float now) {
    if (state == State.ADJUSTING && now - lastTurn >= START_DELAY) run(now);
    if (state == State.RUNNING && now >= endsAt) {
      state = State.RINGING;
      rangAt = endsAt;
      System.out.println("[timer] ringing");
      return true;
    }
    return false;
  }

  /** The alarm was answered with a button press. */
  public void clearAlarm() {
    state = State.IDLE;
    remaining = 0;
    System.out.println("[timer] alarm cleared");
  }

  /** The alarm screen timed out without anyone answering. */
  public void alarmUnanswered() {
    state = State.IDLE;
    remaining = 0;
    missed = true;
    System.out.println("[timer] alarm missed");
  }

  /** A button was pressed: the "timer finished" note on home goes away. */
  public void clearMissed() {
    missed = false;
  }

  public State state() {
    return state;
  }

  public boolean isRinging() {
    return state == State.RINGING;
  }

  public boolean isMissed() {
    return missed;
  }

  /** Seconds left (0 when idle or ringing). */
  public float remaining(float now) {
    if (state == State.RUNNING) return Math.max(0, endsAt - now);
    if (state == State.RINGING) return 0;
    return remaining;
  }

  /** Seconds since the timer reached zero. */
  public float sinceRang(float now) {
    return now - rangAt;
  }

  // --- knob steps: 5 s up to 1 min, 1 min up to 60 min, 5 min above ---

  static float stepUp(float value) {
    if (value < 60) return Math.min(MAX, value + 5);
    if (value < 3600) return Math.min(MAX, value + 60);
    return Math.min(MAX, value + 300);
  }

  static float stepDown(float value) {
    if (value <= 60) return Math.max(0, value - 5);
    if (value <= 3600) return value - 60;
    return value - 300;
  }

  private void run(float now) {
    endsAt = now + remaining;
    state = State.RUNNING;
    System.out.println("[timer] running, " + Math.round(remaining) + " s");
  }
}
