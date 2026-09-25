import java.io.File;
import java.io.FileReader;
import java.io.Reader;

import processing.data.JSONObject;

/**
 * Loads the local settings file (data/config.json).
 *
 * config.json is git-ignored and exists separately on each machine.
 * If it is missing, config.example.json is used instead and a warning is printed.
 *
 * Values are read with a key and a default, for example:
 *   config.getBoolean("fullscreen", false)
 *   config.getString("sources.weather", "fake")   // dot = nested object
 */
public class CoreConfig {

  private JSONObject json = new JSONObject();

  public CoreConfig(File dataFolder) {
    File local = new File(dataFolder, "config.json");
    File example = new File(dataFolder, "config.example.json");

    if (local.exists()) {
      json = load(local);
      System.out.println("[config] Loaded " + local.getPath());
    } else if (example.exists()) {
      json = load(example);
      System.out.println("[config] WARNING: data/config.json not found.");
      System.out.println("[config] Using config.example.json. Copy it to config.json to make local changes.");
    } else {
      System.out.println("[config] WARNING: no config file found, using built-in defaults.");
    }
  }

  public String getString(String key, String fallback) {
    JSONObject parent = parentOf(key);
    String name = lastPart(key);
    if (parent == null || !parent.hasKey(name)) return fallback;
    return parent.getString(name, fallback);
  }

  public boolean getBoolean(String key, boolean fallback) {
    JSONObject parent = parentOf(key);
    String name = lastPart(key);
    if (parent == null || !parent.hasKey(name)) return fallback;
    return parent.getBoolean(name, fallback);
  }

  public int getInt(String key, int fallback) {
    JSONObject parent = parentOf(key);
    String name = lastPart(key);
    if (parent == null || !parent.hasKey(name)) return fallback;
    return parent.getInt(name, fallback);
  }

  public float getFloat(String key, float fallback) {
    JSONObject parent = parentOf(key);
    String name = lastPart(key);
    if (parent == null || !parent.hasKey(name)) return fallback;
    return parent.getFloat(name, fallback);
  }

  // --- helpers ---

  private JSONObject load(File file) {
    try (Reader reader = new FileReader(file)) {
      return new JSONObject(reader);
    } catch (Exception e) {
      System.out.println("[config] ERROR reading " + file.getPath() + ": " + e.getMessage());
      System.out.println("[config] Using built-in defaults.");
      return new JSONObject();
    }
  }

  // For "sources.weather" returns the "sources" object. For "debug" returns the root.
  private JSONObject parentOf(String key) {
    String[] parts = key.split("\\.");
    JSONObject current = json;
    for (int i = 0; i < parts.length - 1; i++) {
      if (!current.hasKey(parts[i])) return null;
      current = current.getJSONObject(parts[i]);
      if (current == null) return null;
    }
    return current;
  }

  private String lastPart(String key) {
    String[] parts = key.split("\\.");
    return parts[parts.length - 1];
  }
}
