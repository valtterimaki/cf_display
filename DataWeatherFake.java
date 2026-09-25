import java.util.Random;

/**
 * Fake weather for development. Temperature drifts, conditions change now and then,
 * and roughly 1 in 10 fetches fails on purpose so error handling gets exercised.
 */
public class DataWeatherFake extends DataSource {

  private final DataStore store;
  private final Random random = new Random();

  private float temperature = 12;
  private DataWeather.Condition condition = DataWeather.Condition.CLEAR;

  public DataWeatherFake(DataStore store) {
    super("weather", 10);
    this.store = store;
  }

  protected void fetch() throws Exception {
    Thread.sleep(300);  // pretend network delay

    if (random.nextFloat() < 0.1f) {
      throw new Exception("simulated network error");
    }

    temperature += (random.nextFloat() - 0.5f) * 1.6f;
    if (random.nextFloat() < 0.2f) {
      DataWeather.Condition[] all = DataWeather.Condition.values();
      condition = all[random.nextInt(all.length)];
    }
    float wind = 2 + random.nextFloat() * 6;

    store.setWeather(new DataWeather(temperature, wind, condition));
  }
}
