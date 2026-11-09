import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Whether someone is at the desk, and whether the device is asleep.
 *
 * Only keeps the state; CoreTriggers decides when to sleep and wake.
 * The device starts asleep, so the first presence of the day brings the welcome.
 */
public class CorePresence {

  /** No presence this long → sleep. Also resets the "present for" count. */
  public static final float SLEEP_AFTER = 5 * 60;

  /** A new day starts at 04:00, so a late night still counts as the previous day. */
  public static final int DAY_START_HOUR = 4;

  private boolean asleep = true;
  private float lastSeen = 0;
  private float presentSince = 0;
  private LocalDate lastWakeDay = null;

  /** Call once per frame with the sensor reading. */
  public void update(boolean detected, float now) {
    if (detected) lastSeen = now;
  }

  public boolean isAsleep() {
    return asleep;
  }

  /** Seconds since presence was last detected. */
  public float awayFor(float now) {
    return now - lastSeen;
  }

  /** Seconds since the device last woke up, i.e. how long someone has been here. */
  public float presentFor(float now) {
    return now - presentSince;
  }

  public void sleep() {
    asleep = true;
  }

  /** Wake up. Returns true if this is the first wake of the day. */
  public boolean wake(LocalDateTime time, float now) {
    asleep = false;
    lastSeen = now;
    presentSince = now;
    LocalDate day = time.minusHours(DAY_START_HOUR).toLocalDate();
    boolean first = !day.equals(lastWakeDay);
    lastWakeDay = day;
    return first;
  }
}
