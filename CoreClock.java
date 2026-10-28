import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/**
 * Wall-clock time: every date and time read goes through here, so config "fakeTime"
 * can make the whole sketch pretend it's another time of day (e.g. morning, to see
 * the calendar while developing at night). now() in cf_display.pde is a different
 * clock: seconds since start, for animation.
 */
public class CoreClock {

  private static Duration offset = Duration.ZERO;

  /** From now on it's this time of day today, running on from there. Call before sources start. */
  public static void fakeTimeOfDay(LocalTime time) {
    offset = Duration.between(LocalDateTime.now(), LocalDate.now().atTime(time));
  }

  public static LocalDateTime now() {
    return LocalDateTime.now().plus(offset);
  }

  public static LocalDate today() {
    return now().toLocalDate();
  }
}
