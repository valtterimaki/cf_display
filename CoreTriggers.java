import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

/**
 * Rules for when data should bring up a screen.
 *
 * Kept separate from the data sources: sources only fetch, triggers only decide.
 * That way a rule keeps working when a fake source is swapped for a real one.
 * Triggers only queue screens — they never interrupt the current one.
 */
public class CoreTriggers {

  private static final int CALENDAR_LEAD_MINUTES = 5;

  private final DataStore store;
  private final CoreScheduler scheduler;

  private final Set<String> announcedEvents = new HashSet<>();
  private float lastCheck = -999;

  public CoreTriggers(DataStore store, CoreScheduler scheduler) {
    this.store = store;
    this.scheduler = scheduler;
  }

  /** Call once per frame. Rules are checked once per second. */
  public void update(float now) {
    if (now - lastCheck < 1) return;
    lastCheck = now;

    checkUpcomingEvents();
  }

  // --- rules ---

  /** An event starts within CALENDAR_LEAD_MINUTES → show the calendar (once per event). */
  private void checkUpcomingEvents() {
    DataCalendar calendar = store.calendar();
    if (calendar == null) return;

    LocalDateTime now = LocalDateTime.now();
    for (DataCalendar.Event event : calendar.events) {
      long secondsUntil = Duration.between(now, event.start).getSeconds();
      boolean soon = secondsUntil > 0 && secondsUntil <= CALENDAR_LEAD_MINUTES * 60;
      if (soon && announcedEvents.add(event.key())) {
        System.out.println("[trigger] '" + event.title + "' starts in " + secondsUntil + " s");
        scheduler.request("calendar", CoreScheduler.PRIORITY_HIGH);
      }
    }
  }
}
