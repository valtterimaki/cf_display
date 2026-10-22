import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Base for anything that fetches data in the background (APIs, files, sensors...).
 *
 * Each source runs on its own background thread and calls fetch() every
 * `intervalSeconds`, so slow network calls never stall the animation.
 * fetch() puts its result into the DataStore. If it throws, the error is
 * recorded, the previous data stays in the store, and it tries again next time.
 *
 *   class DataWeatherSomething extends DataSource {
 *     DataWeatherSomething(DataStore store) { super("weather", 600); ... }
 *     protected void fetch() throws Exception { ...; store.setWeather(result); }
 *   }
 */
public abstract class DataSource {

  public enum Status { WAITING, OK, ERROR }

  private final String name;
  private final float intervalSeconds;

  private volatile Status status = Status.WAITING;
  private volatile long lastSuccessMillis = 0;
  private volatile String lastError = null;

  private ScheduledExecutorService executor;

  protected DataSource(String name, float intervalSeconds) {
    this.name = name;
    this.intervalSeconds = intervalSeconds;
  }

  /** Fetch new data and put it into the store. Runs on a background thread. */
  protected abstract void fetch() throws Exception;

  /** Start fetching: once right away, then every intervalSeconds. */
  public void start() {
    executor = Executors.newSingleThreadScheduledExecutor(runnable -> {
      Thread thread = new Thread(runnable, "data-" + name);
      thread.setDaemon(true);   // don't keep the program alive on exit
      return thread;
    });
    long intervalMillis = (long) (intervalSeconds * 1000);
    executor.scheduleWithFixedDelay(this::runFetch, 0, intervalMillis, TimeUnit.MILLISECONDS);
  }

  // --- info for the debug view ---

  public String name() {
    return name;
  }

  public Status status() {
    return status;
  }

  public String lastError() {
    return lastError;
  }

  /** Seconds since the last successful fetch, or -1 if never. */
  public float secondsSinceUpdate() {
    if (lastSuccessMillis == 0) return -1;
    return (System.currentTimeMillis() - lastSuccessMillis) / 1000f;
  }

  // --- internals ---

  private void runFetch() {
    try {
      fetch();
      status = Status.OK;
      lastSuccessMillis = System.currentTimeMillis();
      lastError = null;
    } catch (Exception | Error e) {
      // Catch everything, Errors too (e.g. a library class failing to load): anything
      // uncaught makes the scheduler silently cancel all future fetches.
      status = Status.ERROR;
      lastError = e.getMessage();
      System.out.println("[data] " + name + " fetch failed: " + e.getMessage());
    }
  }
}
