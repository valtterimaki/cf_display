// cf_display — desk info display
// Main sketch file. See PLAN.md for architecture.

CoreConfig config;

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
}

void draw() {
  background(20, 24, 32);
}
