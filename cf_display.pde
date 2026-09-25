// cf_display — desk info display
// Main sketch file. See PLAN.md for architecture.

CoreConfig config;

// TEMPORARY (step 3): shows one screen on repeat. Replaced by the scheduler in step 4.
CoreScreen currentScreen;

void settings() {
  config = new CoreConfig(new File(sketchPath("data")));

  if (config.getBoolean("fullscreen", false)) {
    fullScreen(P2D);
  } else {
    size(720, 720, P2D);
  }
}

void setup() {
  frameRate(60);
  currentScreen = new ScreenClock();
  currentScreen.begin(now());
}

void draw() {
  currentScreen.update(now());

  // TEMPORARY (step 3): restart the screen when it finishes, with a short gap
  if (currentScreen.isDone()) {
    background(0);
    println("screen DONE, restarting");
    currentScreen = new ScreenClock();
    currentScreen.begin(now());
  }
}

/** Current time in seconds. The one place the sketch reads the clock. */
float now() {
  return millis() / 1000.0;
}
