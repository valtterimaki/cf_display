// cf_display — desk info display
// Main sketch file. See PLAN.md for architecture.

CoreConfig config;
CoreScheduler scheduler;
HwDevice hardware;

boolean debugVisible;

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

  debugVisible = config.getBoolean("debug", false);
  hardware = createHardware(config.getString("hardware", "simulated"));

  scheduler = new CoreScheduler();

  // Screens — registration order is the fallback cycle order
  scheduler.register("clock",    () -> new ScreenClock());
  scheduler.register("weather",  () -> new ScreenWeather());
  scheduler.register("calendar", () -> new ScreenCalendar());

  scheduler.setTransition(new TransitionBasic());
  scheduler.start(now());
}

void draw() {
  hardware.update(now());
  handleActions();
  scheduler.update(now());
}

/** Current time in seconds. The one place the sketch reads the clock. */
float now() {
  return millis() / 1000.0;
}

// --- hardware and input ---

HwDevice createHardware(String type) {
  if (type.equals("pi")) return new HwPi();
  if (!type.equals("simulated")) {
    println("[hw] WARNING: unknown hardware '" + type + "', using simulated");
  }
  return new HwSimulated();
}

/** Global reactions to actions. Anything else goes to the current screen. */
void handleActions() {
  HwAction action;
  while ((action = hardware.pollAction()) != null) {
    println("[input] " + action);
    switch (action.type) {
      case SKIP:
        scheduler.skip();
        break;
      case SHOW_SCREEN:
        java.util.List<String> ids = scheduler.registeredIds();
        if (action.value < ids.size()) {
          scheduler.request(ids.get(action.value), CoreScheduler.PRIORITY_HIGH);
        }
        break;
      case TOGGLE_DEBUG:
        debugVisible = !debugVisible;
        break;
      default:
        scheduler.sendToScreen(action);
        break;
    }
  }
}

// Keyboard and mouse only matter in simulated mode.

void keyPressed() {
  if (hardware instanceof HwSimulated) {
    ((HwSimulated) hardware).keyPressed(key, keyCode);
  }
}

void mouseWheel(MouseEvent event) {
  if (hardware instanceof HwSimulated) {
    ((HwSimulated) hardware).mouseWheel(event.getCount());
  }
}
