/**
 * Something the user wants to happen, independent of which button or key caused it.
 *
 * Hardware (real or simulated) turns presses into actions. The rest of the code
 * only reacts to actions, so button mappings can change without touching screens.
 *
 * Some actions carry a value:
 *   SHOW_SCREEN   value = screen number (0 = first registered screen)
 *   ENCODER_TURN  value = steps turned (+1 clockwise, -1 counter-clockwise)
 */
public class HwAction {

  public enum Type {
    SKIP,           // current screen wraps up early
    SHOW_SCREEN,    // queue a specific screen
    TOGGLE_DEBUG,   // show/hide the debug view
    ENCODER_TURN,   // knob turned
    ENCODER_PRESS   // knob pressed
  }

  public final Type type;
  public final int value;

  public HwAction(Type type) {
    this(type, 0);
  }

  public HwAction(Type type, int value) {
    this.type = type;
    this.value = value;
  }

  public String toString() {
    return value == 0 ? type.toString() : type + "(" + value + ")";
  }
}
