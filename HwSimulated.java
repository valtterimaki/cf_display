import java.util.concurrent.ConcurrentLinkedQueue;

import processing.core.PConstants;

/**
 * Desktop stand-in for the device hardware.
 *
 * The sketch forwards key and mouse wheel events here. Key map:
 *
 *   Space / →      SKIP
 *   1 – 9          SHOW_SCREEN (1 = first registered screen)
 *   D              TOGGLE_DEBUG
 *   , / .          ENCODER_TURN -1 / +1   (mouse wheel works too)
 *   Enter          ENCODER_PRESS
 *   - / +          light level down / up
 *
 * LEDs just store their brightness; the debug view shows them.
 */
public class HwSimulated implements HwDevice {

  private static final int LED_COUNT = 3;

  private final ConcurrentLinkedQueue<HwAction> actions = new ConcurrentLinkedQueue<>();
  private final float[] leds = new float[LED_COUNT];
  private float light = 0.5f;

  // --- events forwarded from the sketch ---

  public void keyPressed(char key, int keyCode) {
    if (key == ' ' || keyCode == PConstants.RIGHT) {
      push(new HwAction(HwAction.Type.SKIP));
    } else if (key >= '1' && key <= '9') {
      push(new HwAction(HwAction.Type.SHOW_SCREEN, key - '1'));
    } else if (key == 'd' || key == 'D') {
      push(new HwAction(HwAction.Type.TOGGLE_DEBUG));
    } else if (key == ',') {
      push(new HwAction(HwAction.Type.ENCODER_TURN, -1));
    } else if (key == '.') {
      push(new HwAction(HwAction.Type.ENCODER_TURN, 1));
    } else if (key == PConstants.ENTER || key == PConstants.RETURN) {
      push(new HwAction(HwAction.Type.ENCODER_PRESS));
    } else if (key == '-') {
      setLight(light - 0.1f);
    } else if (key == '+' || key == '=') {
      setLight(light + 0.1f);
    }
  }

  /** Mouse wheel: count > 0 = scrolled down. Treated as encoder steps. */
  public void mouseWheel(int count) {
    if (count != 0) push(new HwAction(HwAction.Type.ENCODER_TURN, count));
  }

  // --- HwDevice ---

  public void update(float now) {
    // Nothing to poll: input arrives through the forwarded events.
  }

  public HwAction pollAction() {
    return actions.poll();
  }

  public float lightLevel() {
    return light;
  }

  public int ledCount() {
    return LED_COUNT;
  }

  public void setLed(int index, float brightness) {
    if (index >= 0 && index < LED_COUNT) leds[index] = clamp(brightness);
  }

  public float getLed(int index) {
    return (index >= 0 && index < LED_COUNT) ? leds[index] : 0;
  }

  public String name() {
    return "simulated";
  }

  // --- internals ---

  private void push(HwAction action) {
    actions.add(action);
  }

  private void setLight(float value) {
    light = clamp(Math.round(value * 10) / 10f);
    System.out.println("[hw] light level " + light);
  }

  private float clamp(float v) {
    return Math.max(0, Math.min(1, v));
  }
}
