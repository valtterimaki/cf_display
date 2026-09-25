/**
 * Easing functions. Each takes x in 0..1 and returns a shaped value
 * (0 at the start, 1 at the end; "back" and "elastic" overshoot in between).
 *
 * Usage with a timeline:
 *   float x = CoreEase.outCubic(tl.progress(0.5f, 1.2f));
 *   float pos = lerp(100, 600, x);
 *
 * in    = starts slow, ends fast
 * out   = starts fast, ends slow
 * inOut = slow at both ends
 */
public class CoreEase {

  public static float linear(float x) {
    return x;
  }

  // --- sine: gentle ---

  public static float inSine(float x) {
    return 1 - (float) Math.cos(x * Math.PI / 2);
  }

  public static float outSine(float x) {
    return (float) Math.sin(x * Math.PI / 2);
  }

  public static float inOutSine(float x) {
    return -((float) Math.cos(Math.PI * x) - 1) / 2;
  }

  // --- quad: medium ---

  public static float inQuad(float x) {
    return x * x;
  }

  public static float outQuad(float x) {
    return 1 - (1 - x) * (1 - x);
  }

  public static float inOutQuad(float x) {
    return x < 0.5f ? 2 * x * x : 1 - (float) Math.pow(-2 * x + 2, 2) / 2;
  }

  // --- cubic: stronger ---

  public static float inCubic(float x) {
    return x * x * x;
  }

  public static float outCubic(float x) {
    return 1 - (float) Math.pow(1 - x, 3);
  }

  public static float inOutCubic(float x) {
    return x < 0.5f ? 4 * x * x * x : 1 - (float) Math.pow(-2 * x + 2, 3) / 2;
  }

  // --- expo: very strong ---

  public static float inExpo(float x) {
    return x == 0 ? 0 : (float) Math.pow(2, 10 * x - 10);
  }

  public static float outExpo(float x) {
    return x == 1 ? 1 : 1 - (float) Math.pow(2, -10 * x);
  }

  // --- overshoot ---

  /** Goes a little past the end, then settles back. */
  public static float outBack(float x) {
    float c1 = 1.70158f;
    float c3 = c1 + 1;
    return 1 + c3 * (float) Math.pow(x - 1, 3) + c1 * (float) Math.pow(x - 1, 2);
  }

  /** Springy wobble at the end. */
  public static float outElastic(float x) {
    if (x == 0 || x == 1) return x;
    float c4 = (float) (2 * Math.PI / 3);
    return (float) (Math.pow(2, -10 * x) * Math.sin((x * 10 - 0.75) * c4)) + 1;
  }

  /** Bounces like a dropped ball. */
  public static float outBounce(float x) {
    float n1 = 7.5625f;
    float d1 = 2.75f;
    if (x < 1 / d1) {
      return n1 * x * x;
    } else if (x < 2 / d1) {
      x -= 1.5f / d1;
      return n1 * x * x + 0.75f;
    } else if (x < 2.5f / d1) {
      x -= 2.25f / d1;
      return n1 * x * x + 0.9375f;
    } else {
      x -= 2.625f / d1;
      return n1 * x * x + 0.984375f;
    }
  }
}
