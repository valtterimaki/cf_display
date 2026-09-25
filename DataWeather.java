/**
 * Current weather. Immutable: sources create a new one on every update.
 */
public class DataWeather {

  public enum Condition { CLEAR, CLOUDY, RAIN, SNOW, FOG, THUNDER }

  public final float temperature;   // °C
  public final float windSpeed;     // m/s
  public final Condition condition;

  public DataWeather(float temperature, float windSpeed, Condition condition) {
    this.temperature = temperature;
    this.windSpeed = windSpeed;
    this.condition = condition;
  }
}
