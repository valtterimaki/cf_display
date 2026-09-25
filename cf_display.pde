// cf_display — desk info display
// Main sketch file. See PLAN.md for architecture.

CoreConfig config;
CoreScheduler scheduler;

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

  scheduler = new CoreScheduler();

  // Screens — registration order is the fallback cycle order
  scheduler.register("clock",    () -> new ScreenClock());
  scheduler.register("weather",  () -> new ScreenWeather());
  scheduler.register("calendar", () -> new ScreenCalendar());

  scheduler.setTransition(new TransitionBasic());
  scheduler.start(now());
}

void draw() {
  scheduler.update(now());
}

/** Current time in seconds. The one place the sketch reads the clock. */
float now() {
  return millis() / 1000.0;
}
