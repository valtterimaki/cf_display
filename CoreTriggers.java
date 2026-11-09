import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Rules for which screen comes when.
 *
 * Kept separate from the data sources: sources only fetch, triggers only decide.
 *
 * - Visits: when home is done, planVisit() lists the screens to show before home again:
 *   event alert and break reminder when they apply, then the whole rotation.
 * - Sleep and wake, from presence (CorePresence).
 * - Timer alarm (CoreTimer).
 * - Browsing with the knob: a corner layer picks a screen, which opens after a pause.
 */
public class CoreTriggers {

  /** The rotation's base order. Browsing always uses this; visits run it through rotationNow(). */
  public static final List<String> ROTATION = Collections.unmodifiableList(Arrays.asList(
    "calendar", "tasks", "weather", "bus", "presence", "graphics"));

  private static final int EVENT_LEAD_MINUTES = 15;    // alert from this long before an event...
  private static final int EVENT_TRAIL_MINUTES = 10;   // ...until this long after it started
  private static final float BREAK_AFTER = 30 * 60;
  private static final int BUS_FROM_HOUR = 14;
  private static final float BROWSE_DELAY = 3;         // seconds after the last knob turn

  private final DataStore store;
  private final CoreScheduler scheduler;
  private final CorePresence presence;
  private final CoreTimer timer;

  private float lastNow = 0;
  private int browseIndex = -1;   // index into browseList(), -1 = not browsing
  private float lastBrowseTurn = 0;

  public CoreTriggers(DataStore store, CoreScheduler scheduler, CorePresence presence, CoreTimer timer) {
    this.store = store;
    this.scheduler = scheduler;
    this.presence = presence;
    this.timer = timer;
    scheduler.setVisitPlanner(() -> planVisit(CoreClock.now(), lastNow));
  }

  /** Call once per frame, with the presence sensor reading. */
  public void update(float now, boolean presenceDetected) {
    lastNow = now;

    presence.update(presenceDetected, now);
    if (presence.isAsleep()) {
      if (presenceDetected) wake(now);
    } else if (presence.awayFor(now) >= CorePresence.SLEEP_AFTER) {
      sleep(now);
    }

    // While asleep the alarm waits: wake() shows it after the welcome
    if (timer.update(now) && !presence.isAsleep()) scheduler.interrupt("alarm", now);

    if (browseIndex >= 0 && now - lastBrowseTurn >= BROWSE_DELAY) {
      String id = browseList().get(browseIndex);
      browseIndex = -1;
      scheduler.interrupt(id, now);
    }
  }

  // --- visits ---

  /** Screens for one visit, decided once when it starts. */
  public List<String> planVisit(LocalDateTime time, float now) {
    List<String> plan = new ArrayList<>();
    if (eventAlertDue(time)) plan.add("eventAlert");
    if (presence.presentFor(now) >= BREAK_AFTER) plan.add("breakReminder");
    plan.addAll(rotationNow(time));
    return plan;
  }

  /**
   * The rotation for a visit starting now: the base order, minus screens that don't
   * apply right now. Rules that reorder or skip screens go here, one block each.
   */
  public List<String> rotationNow(LocalDateTime time) {
    List<String> rotation = new ArrayList<>(ROTATION);
    if (time.getHour() < BUS_FROM_HOUR) rotation.remove("bus");
    return rotation;
  }

  /** An event starts within EVENT_LEAD_MINUTES or started under EVENT_TRAIL_MINUTES ago. */
  boolean eventAlertDue(LocalDateTime time) {
    DataCalendar calendar = store.calendar();
    if (calendar == null) return false;
    for (DataCalendar.Event event : calendar.events) {
      if (event.allDay) continue;
      long secondsUntil = Duration.between(time, event.start).getSeconds();
      if (secondsUntil < EVENT_LEAD_MINUTES * 60 && secondsUntil > -EVENT_TRAIL_MINUTES * 60) return true;
    }
    return false;
  }

  // --- sleep and wake ---

  public boolean isAsleep() {
    return presence.isAsleep();
  }

  /** Wake up (presence detected, or any button press). */
  public void wake(float now) {
    boolean firstToday = presence.wake(CoreClock.now(), now);
    System.out.println("[trigger] wake" + (firstToday ? ", first time today" : ""));
    scheduler.interrupt(firstToday ? "welcome" : "welcomeShort", now);
    if (timer.isRinging()) scheduler.showNext("alarm");   // it went off while asleep
  }

  private void sleep(float now) {
    System.out.println("[trigger] no presence, sleep");
    presence.sleep();
    browseIndex = -1;
    scheduler.interrupt("sleep", now);
  }

  // --- browsing with the knob ---

  /** Knob turned outside the set timer screen: move the selection. */
  public void browse(int steps, float now) {
    List<String> list = browseList();
    if (browseIndex < 0) {
      // Start from the screen that is showing, or from home
      browseIndex = list.indexOf(scheduler.currentId());
      if (browseIndex < 0) browseIndex = list.size() - 1;
    }
    browseIndex = Math.floorMod(browseIndex + steps, list.size());
    lastBrowseTurn = now;
  }

  /** The screen selected in the browse layer, or null when not browsing. */
  public String browseSelection() {
    return browseIndex >= 0 ? browseList().get(browseIndex) : null;
  }

  /** The whole rotation in its base order, then home. No rules applied. */
  private List<String> browseList() {
    List<String> list = new ArrayList<>(ROTATION);
    list.add("home");
    return list;
  }
}
