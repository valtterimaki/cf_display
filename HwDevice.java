/**
 * Everything physical on the device: buttons/knobs in, LEDs out, sensors.
 *
 * Two implementations, chosen by "hardware" in config.json:
 *   HwSimulated  — desktop: keyboard and mouse stand in for the hardware
 *   HwPi         — device: real GPIO
 */
public interface HwDevice {

  /** Call once per frame. Reads inputs and updates outputs. */
  void update(float now);

  /** Next action waiting to be handled, or null if none. */
  HwAction pollAction();

  /** Ambient light, 0 = dark, 1 = bright. */
  float lightLevel();

  /** Number of LEDs on the device. */
  int ledCount();

  /** Set LED brightness, 0 = off, 1 = full. */
  void setLed(int index, float brightness);

  /** Current LED brightness (for the debug view). */
  float getLed(int index);

  /** Short name for logs and the debug view. */
  String name();
}
