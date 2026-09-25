// cf_display — desk info display
// Main sketch file. See PLAN.md for architecture.

CoreConfig config;

// TEMPORARY (step 2): timing toolkit test. Replaced by screens in step 3.
CoreTimeline testTimeline;
float flashUntil = 0;

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
  testTimeline = new CoreTimeline(now());
}

void draw() {
  testTimeline.update(now());
  drawTimingTest();
}

/** Current time in seconds. The one place the sketch reads the clock. */
float now() {
  return millis() / 1000.0;
}

// TEMPORARY (step 2)
void drawTimingTest() {
  CoreTimeline tl = testTimeline;
  background(20, 24, 32);

  // Loop the test every 4 seconds
  if (tl.t() >= 4) tl.restart(now());

  // Event: fires exactly once per loop at 2.5 s
  if (tl.once(2.5)) {
    println("once(2.5) fired at t = " + nf(tl.t(), 1, 3));
    flashUntil = now() + 0.15;
  }
  if (now() < flashUntil) background(90, 40, 40);

  // Three balls, same timing window (0.5 s .. 2.0 s), different easing
  float p = tl.progress(0.5, 1.5);
  noStroke();
  fill(240);
  ellipse(lerp(160, 620, CoreEase.linear(p)), 260, 40, 40);
  ellipse(lerp(160, 620, CoreEase.inOutCubic(p)), 360, 40, 40);
  ellipse(lerp(160, 620, CoreEase.outBack(p)), 460, 40, 40);

  // Blink every 0.5 s
  if (tl.every(0.5)) println("every(0.5) at t = " + nf(tl.t(), 1, 3));

  fill(160);
  textSize(16);
  text("t = " + nf(tl.t(), 1, 2), 20, 30);
  text("linear", 20, 265);
  text("inOutCubic", 20, 365);
  text("outBack", 20, 465);
}
