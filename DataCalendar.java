import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Calendar events. Immutable: sources create a new one on every update.
 */
public class DataCalendar {

  public static class Event {
    public final String calendar;       // which calendar it came from, e.g. "Work"
    public final String title;
    public final LocalDateTime start;   // local time on this machine
    public final LocalDateTime end;
    public final boolean allDay;        // start and end are then midnights

    public Event(String calendar, String title, LocalDateTime start, LocalDateTime end, boolean allDay) {
      this.calendar = calendar;
      this.title = title;
      this.start = start;
      this.end = end;
      this.allDay = allDay;
    }

    /** Identifies the event, e.g. to avoid announcing it twice. */
    public String key() {
      return title + "@" + start;
    }
  }

  /** All events, sorted by start time. */
  public final List<Event> events;

  public DataCalendar(List<Event> events) {
    List<Event> sorted = new ArrayList<>(events);
    sorted.sort((a, b) -> a.start.compareTo(b.start));
    this.events = Collections.unmodifiableList(sorted);
  }

  /** Events that haven't ended yet, soonest first, at most `max`. */
  public List<Event> upcoming(LocalDateTime now, int max) {
    List<Event> result = new ArrayList<>();
    for (Event e : events) {
      if (e.end.isAfter(now)) result.add(e);
      if (result.size() >= max) break;
    }
    return result;
  }
}
