import java.io.File;
import java.io.FileReader;
import java.io.Reader;
import java.util.ArrayList;
import java.util.List;

import processing.data.JSONObject;

/**
 * Settings of the CRT effect (fx_crt.pde, data/shaders/crt.frag), from data/crt.json.
 *
 * Committed to git, so the look tuned on one machine reaches the others.
 * Edited live in the CRT panel (C key) and saved back with S. Over SSH:
 * edit data/crt.json and restart the sketch. Missing keys keep their defaults.
 *
 * Also works out the filter weights the shader needs, so it does no exp() per pixel.
 */
public class CoreCrt {

  /** One adjustable value. On/off settings are 0 or 1 with step 1. */
  public static class Setting {
    public final String key;
    public final float defaultValue, min, max, step;
    public final String unit;
    public final String help;
    public float value;

    Setting(String key, float defaultValue, float min, float max, float step, String unit, String help) {
      this.key = key;
      this.defaultValue = defaultValue;
      this.min = min;
      this.max = max;
      this.step = step;
      this.unit = unit;
      this.help = help;
      this.value = defaultValue;
    }

    public boolean isOnOff() {
      return min == 0 && max == 1 && step == 1;
    }
  }

  /** The most taps the shader can take (uniform arrays are sized 2 * TAPS + 1). */
  public static final int MAX_TAPS = 10;

  public final List<Setting> all = new ArrayList<>();

  // In panel order. Defaults = the Shadertoy/Processing prototype.
  public final Setting enabled     = add("enabled",     1,     0,    1,    1,     "",    "Effect on/off");
  public final Setting pal         = add("pal",         1,     0,    1,    1,     "",    "1 = PAL (fine dots), 0 = NTSC (coarse checkerboard)");
  public final Setting taps        = add("taps",        6,     2,    MAX_TAPS, 1, "",    "Filter width. Reads per pixel = 2 x taps + 1. The speed knob");
  public final Setting chromaBlur  = add("chromaBlur",  3,     0.5f, 5,    0.25f, "px",  "Colour bleed width (at most taps / 2)");
  public final Setting chromaDelay = add("chromaDelay", 2,     0,    8,    1,     "px",  "Colour shifted right of edges (at most taps - 2)");
  public final Setting leak        = add("leak",        0.10f, 0,    0.4f, 0.02f, "",    "Dot crawl strength. Higher is also sharper");
  public final Setting chromaGain  = add("chromaGain",  1,     0,    2,    0.05f, "",    "Saturation");
  public final Setting hue         = add("hue",         0,     -30,  30,   1,     "deg", "Tint");
  public final Setting nonlin      = add("nonlin",      0.05f, 0,    0.2f, 0.01f, "",    "Hue and saturation error that depends on brightness");
  public final Setting noise       = add("noise",       0.01f, 0,    0.1f, 0.002f, "",   "RF snow");
  public final Setting clipHi      = add("clipHi",      1.30f, 1,    1.6f, 0.02f, "",    "Limits bright saturated yellow and cyan");

  private final File file;

  public CoreCrt(File file) {
    this.file = file;
    load();
  }

  public void load() {
    if (!file.exists()) {
      System.out.println("[crt] " + file.getPath() + " not found, using defaults");
      return;
    }
    try (Reader reader = new FileReader(file)) {
      JSONObject json = new JSONObject(reader);
      for (Setting s : all) {
        if (json.hasKey(s.key)) s.value = json.getFloat(s.key);
      }
      System.out.println("[crt] Loaded " + file.getPath());
    } catch (Exception e) {
      System.out.println("[crt] ERROR reading " + file.getPath() + ": " + e.getMessage() + ", using defaults");
    }
    limit();
  }

  public void save() {
    JSONObject json = new JSONObject();
    for (Setting s : all) {
      if (s.step >= 1) json.setInt(s.key, Math.round(s.value));
      else json.setDouble(s.key, Math.round(s.value * 1000) / 1000.0);   // 0.01, not 0.009999999776
    }
    if (json.save(file, "indent=2")) {
      System.out.println("[crt] Saved " + file.getPath());
    } else {
      System.out.println("[crt] ERROR saving " + file.getPath());
    }
  }

  /** Changes a setting by `steps` steps, keeping every setting within its limits. */
  public void change(Setting s, int steps) {
    s.value += steps * s.step;
    limit();
  }

  public void reset(Setting s) {
    s.value = s.defaultValue;
    limit();
  }

  /** The highest value a setting can have right now (some depend on taps). */
  public float maxOf(Setting s) {
    // The shader only reads taps pixels to each side. A wider blur would be cut off
    // (and come out narrower than asked), and the brightness filter needs 2 pixels
    // beyond the delay.
    if (s == chromaBlur) return Math.min(s.max, Math.round(taps.value) / 2.0f);
    if (s == chromaDelay) return Math.min(s.max, Math.round(taps.value) - 2);
    return s.max;
  }

  public boolean isOn() {
    return enabled.value > 0.5f;
  }

  public int tapCount() {
    return Math.round(taps.value);
  }

  public boolean isPal() {
    return pal.value > 0.5f;
  }

  // --- filter weights for the shader (arrays of 2 * taps + 1, tap `taps` is the centre) ---

  /** Gaussian colour filter weights. */
  public void chromaWeights(float[] out) {
    int n = tapCount();
    float sigma = chromaBlur.value;
    for (int i = 0; i < 2 * n + 1; i++) {
      float k = i - n;
      out[i] = (float) Math.exp(-0.5 * k * k / (sigma * sigma));
    }
  }

  /** Sum of the weights at even (0) or odd (1) tap positions. */
  public float weightSum(float[] weights, int parity) {
    float sum = 0;
    for (int i = parity; i < 2 * tapCount() + 1; i += 2) sum += weights[i];
    return sum;
  }

  /**
   * Brightness filter weights. The [1,2,2,2,1]/8 kernel removes the subcarrier
   * completely (any 4 neighbouring samples of it add up to 0); `leak` mixes some of
   * the unfiltered pixel back in, which brings back dot crawl and sharpness.
   * The taps are centred on the colour taps' centre + chromaDelay, i.e. this pixel.
   */
  public void lumaWeights(float[] out) {
    int n = tapCount();
    int centre = n + Math.round(chromaDelay.value);
    float keep = 1 - leak.value;
    for (int i = 0; i < 2 * n + 1; i++) out[i] = 0;
    out[centre - 2] = keep * 1 / 8f;
    out[centre - 1] = keep * 2 / 8f;
    out[centre]     = keep * 2 / 8f + leak.value;
    out[centre + 1] = keep * 2 / 8f;
    out[centre + 2] = keep * 1 / 8f;
  }

  // --- internals ---

  private Setting add(String key, float defaultValue, float min, float max, float step, String unit, String help) {
    Setting s = new Setting(key, defaultValue, min, max, step, unit, help);
    all.add(s);
    return s;
  }

  // Taps first: the limits of chromaBlur and chromaDelay depend on it.
  // Values snap to whole steps, so repeated changes don't drift (0.1 + 0.02 + ...).
  private void limit() {
    snap(taps);
    for (Setting s : all) snap(s);
  }

  private void snap(Setting s) {
    float v = Math.round(s.value / s.step) * s.step;
    s.value = Math.max(s.min, Math.min(maxOf(s), v));
  }
}
