// cf_display — desk info display
// Main sketch file. See PLAN.md for architecture.

CoreConfig config;
CoreScheduler scheduler;
CoreTriggers triggers;
HwDevice hardware;
DataStore store;

// Draws per second. 50 to match the videos (After Effects renders at 50 fps).
final int FRAME_RATE = 50;

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
  frameRate(FRAME_RATE);

  debugVisible = config.getBoolean("debug", false);
  hardware = createHardware(config.getString("hardware", "simulated"));

  store = new DataStore();
  store.addSource(createWeatherSource(config.getString("sources.weather", "fake")));
  store.addSource(createCalendarSource(config.getString("sources.calendar", "fake")));

  // After starting the sources, so their first fetch runs while fonts load
  loadAssets();
  if (debugVisible) charBlockSelfCheck();

  scheduler = new CoreScheduler();

  // Screens — registration order is the fallback cycle order
  //scheduler.register("example",  () -> new ScreenExample());   // learning example (see screen_example.pde)
  //scheduler.register("clock",    () -> new ScreenClock());
  //scheduler.register("weather",  () -> new ScreenWeather());
  //scheduler.register("calendar", () -> new ScreenCalendar());
  scheduler.register("charblock", () -> new ScreenCharBlock());   // character block demo
  scheduler.register("rooster",  () -> new ScreenRooster());

  scheduler.setTransition(new TransitionBasic());
  scheduler.start(now());

  triggers = new CoreTriggers(store, scheduler);
}

void draw() {
  debugBeginFrame();

  hardware.update(now());
  handleActions();
  triggers.update(now());
  scheduler.update(now());

  debugEndFrame();
  if (debugVisible) drawDebugOverlay();
}

/** Current time in seconds. The one place the sketch reads the clock. */
float now() {
  return millis() / 1000.0;
}

// --- data sources ---
// Real sources get added here later, e.g. "openmeteo" → new DataWeatherOpenMeteo(store)

DataSource createWeatherSource(String type) {
  if (!type.equals("fake")) println("[data] WARNING: unknown weather source '" + type + "', using fake");
  return new DataWeatherFake(store);
}

DataSource createCalendarSource(String type) {
  if (type.equals("ics")) return new DataCalendarIcs(store, config.getArray("calendars"));
  if (!type.equals("fake")) println("[data] WARNING: unknown calendar source '" + type + "', using fake");
  return new DataCalendarFake(store);
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
