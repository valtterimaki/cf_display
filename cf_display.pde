// cf_display — desk info display
// Main sketch file. See PLAN.md for architecture.

CoreConfig config;
CoreScheduler scheduler;
CoreTriggers triggers;
CorePresence presence;
CoreTimer timer;
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
  loadCaptureFrames();
  String fakeTime = config.getString("fakeTime", "");
  if (!fakeTime.isEmpty()) {
    CoreClock.fakeTimeOfDay(java.time.LocalTime.parse(fakeTime));
    println("[config] fake time of day: " + fakeTime);
  }
  hardware = createHardware(config.getString("hardware", "simulated"));

  store = new DataStore();
  store.addSource(createWeatherSource(config.getString("sources.weather", "fake")));
  store.addSource(createCalendarSource(config.getString("sources.calendar", "fake")));

  // After starting the sources, so their first fetch runs while fonts load
  loadAssets();
  if (debugVisible) {
    charBlockSelfCheck();
    calendarSelfCheck();
    flowSelfCheck();
  }

  scheduler = new CoreScheduler();
  presence = new CorePresence();
  timer = new CoreTimer();

  // Screens. Which one shows when is decided by CoreTriggers.
  //scheduler.register("example",    () -> new ScreenExample());   // learning example (see screen_example.pde)
  scheduler.register("home",          () -> new ScreenHome());
  scheduler.register("sleep",         () -> new ScreenSleep());
  scheduler.register("welcome",       () -> new ScreenPlaceholder("Welcome", "First wake of the day: special welcome content", 10));
  scheduler.register("welcomeShort",  () -> new ScreenPlaceholder("Welcome back", "Shorter welcome after waking again", 5));
  scheduler.register("settimer",      () -> new ScreenSetTimer());
  scheduler.register("alarm",         () -> new ScreenAlarm());
  scheduler.register("eventAlert",    () -> new ScreenPlaceholder("Event alert", "Soft reminder: an event starts soon or just started", 15));
  scheduler.register("breakReminder", () -> new ScreenPlaceholder("Break reminder", "You have been here over 30 minutes", 15));

  // The rotation (order and rules in CoreTriggers)
  scheduler.register("calendar",      () -> new ScreenCalendar());
  scheduler.register("tasks",         () -> new ScreenPlaceholder("Tasks", "Task list", 15));
  scheduler.register("weather",       () -> new ScreenWeather());
  scheduler.register("bus",           () -> new ScreenPlaceholder("Bus timetables", "Next departures", 15));
  scheduler.register("presence",      () -> new ScreenPlaceholder("Presence timer", "How long you have been at the desk", 15));
  scheduler.register("graphics",      () -> new ScreenPlaceholder("Nice graphics", "General nice graphics", 15));

  scheduler.setHome("home");
  scheduler.setTransition(new TransitionBasic());
  triggers = new CoreTriggers(store, scheduler, presence, timer);
  scheduler.start("sleep", now());   // presence wakes it on the first frame
}

void draw() {
  debugBeginFrame();

  hardware.update(now());
  handleActions();
  triggers.update(now(), hardware.presence());
  scheduler.update(now());
  drawBrowseLayer();

  debugEndFrame();
  if (debugVisible) drawDebugOverlay();
  captureUpdate();
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

/**
 * Routes input, in this order:
 *   asleep          → any press wakes the device
 *   alarm ringing   → any press clears it
 *   set timer open  → the screen handles it
 *   otherwise       → timer button opens set timer, knob browses screens
 */
void handleActions() {
  HwAction action;
  while ((action = hardware.pollAction()) != null) {
    println("[input] " + action);
    if (action.type == HwAction.Type.TOGGLE_DEBUG) {
      debugVisible = !debugVisible;
      continue;
    }
    timer.clearMissed();

    if (triggers.isAsleep()) {
      triggers.wake(now());
    } else if (timer.isRinging()) {
      timer.clearAlarm();
      scheduler.interrupt("home", now());
    } else if ("settimer".equals(scheduler.currentId())) {
      scheduler.sendToScreen(action);
    } else {
      switch (action.type) {
        case TIMER_BUTTON:
          scheduler.interrupt("settimer", now());
          break;
        case ENCODER_TURN:
          triggers.browse(action.value, now());
          break;
        case SKIP:
          scheduler.skip();
          break;
        case SHOW_SCREEN:
          if (action.value < CoreTriggers.ROTATION.size()) {
            scheduler.switchTo(CoreTriggers.ROTATION.get(action.value), now());
          }
          break;
        default:
          scheduler.sendToScreen(action);
          break;
      }
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
