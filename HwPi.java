/**
 * Real device hardware via GPIO.
 *
 * STUB: the GPIO library (Pi4J, processing.io or other) is not chosen yet.
 * For now it produces no input, reports full light, and remembers LED values.
 */
public class HwPi implements HwDevice {

  private static final int LED_COUNT = 3;

  private final float[] leds = new float[LED_COUNT];

  public HwPi() {
    System.out.println("[hw] HwPi is a stub — no GPIO input or output yet.");
  }

  public void update(float now) {
    // TODO: read buttons, encoder and light sensor; turn changes into actions.
  }

  public HwAction pollAction() {
    return null;
  }

  public float lightLevel() {
    return 1;
  }

  public int ledCount() {
    return LED_COUNT;
  }

  public void setLed(int index, float brightness) {
    // TODO: drive the real LED.
    if (index >= 0 && index < LED_COUNT) leds[index] = Math.max(0, Math.min(1, brightness));
  }

  public float getLed(int index) {
    return (index >= 0 && index < LED_COUNT) ? leds[index] : 0;
  }

  public String name() {
    return "pi (stub)";
  }
}
