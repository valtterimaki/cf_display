import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Fake calendar for development. Events are placed relative to program start.
 * The first one starts 5.5 minutes after launch, so the "event coming up" trigger
 * (5 minutes ahead) fires about 30 seconds after starting.
 */
public class DataCalendarFake extends DataSource {

  private final DataStore store;
  private final List<DataCalendar.Event> events = new ArrayList<>();

  public DataCalendarFake(DataStore store) {
    super("calendar", 30);
    this.store = store;

    LocalDateTime start = LocalDateTime.now().withNano(0);
    addEvent("Stand-up",        start.plusSeconds(330), 15);
    addEvent("Design review",   start.plusMinutes(45),  60);
    addEvent("Lunch",           start.plusMinutes(130), 45);
    addEvent("1:1",             start.plusMinutes(240), 30);
    addEvent("Friday beers",    start.plusMinutes(420), 120);
  }

  protected void fetch() throws Exception {
    Thread.sleep(200);  // pretend network delay
    store.setCalendar(new DataCalendar(events));
  }

  private void addEvent(String title, LocalDateTime startTime, int minutes) {
    events.add(new DataCalendar.Event(title, startTime, startTime.plusMinutes(minutes)));
  }
}
