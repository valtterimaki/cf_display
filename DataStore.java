import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * The latest data from all sources, in one place.
 *
 * Sources write here from background threads; screens read from here while drawing.
 * Each piece of data is an immutable object that gets replaced whole, so a screen
 * never sees a half-updated value.
 *
 * A value is null until its source has fetched successfully once — screens
 * should handle that (e.g. show "--").
 */
public class DataStore {

  private volatile DataWeather weather = null;
  private volatile DataCalendar calendar = null;

  private final List<DataSource> sources = new CopyOnWriteArrayList<>();

  // --- sources ---

  /** Add a source and start it fetching. */
  public void addSource(DataSource source) {
    sources.add(source);
    source.start();
    System.out.println("[data] started source: " + source.name() + " (" + source.getClass().getSimpleName() + ")");
  }

  public List<DataSource> sources() {
    return sources;
  }

  // --- data ---

  public DataWeather weather() {
    return weather;
  }

  public void setWeather(DataWeather weather) {
    this.weather = weather;
  }

  public DataCalendar calendar() {
    return calendar;
  }

  public void setCalendar(DataCalendar calendar) {
    this.calendar = calendar;
  }
}
