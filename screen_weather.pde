// Placeholder screen: weather.
// No real data yet (comes in step 6). Intro: sun rises. Outro: sun sets.

class ScreenWeather extends CoreScreen {

  final float INTRO_LENGTH = 1.2;
  final float MAIN_LENGTH = 6.0;
  final float OUTRO_LENGTH = 0.9;

  final float SUN_Y = 280;
  final float SUN_SIZE = 180;

  void drawIntro() {
    background(24, 30, 44);
    float rise = CoreEase.outCubic(tl.progress(0, 1.0));
    drawSun(lerp(height + SUN_SIZE, SUN_Y, rise));
    drawLabel(255 * tl.progress(0.6, 0.6));

    if (tl.t() >= INTRO_LENGTH) nextPhase();
  }

  void drawMain() {
    background(24, 30, 44);
    drawSun(SUN_Y + sin(tl.t() * 1.5) * 6);   // gentle bob
    drawLabel(255);

    if (tl.t() >= MAIN_LENGTH) nextPhase();
  }

  void drawOutro() {
    background(24, 30, 44);
    float set = CoreEase.inCubic(tl.progress(0, OUTRO_LENGTH));
    drawSun(lerp(SUN_Y, height + SUN_SIZE, set));
    drawLabel(255 * (1 - tl.progress(0, 0.3)));

    if (tl.t() >= OUTRO_LENGTH) nextPhase();
  }

  void drawSun(float y) {
    noStroke();
    fill(250, 200, 90);
    ellipse(width / 2, y, SUN_SIZE, SUN_SIZE);
  }

  void drawLabel(float alpha) {
    DataWeather weather = store.weather();   // null until the first fetch succeeds

    String temperature = weather != null ? fmtTemperature(weather.temperature) : "--°";
    String details = weather != null
      ? weather.condition + "   wind " + fmtDecimal(weather.windSpeed, 1) + " m/s"
      : "no data yet";

    fill(240, alpha);
    textAlign(CENTER, CENTER);
    textSize(64);
    text(temperature, width / 2, 500);
    textSize(22);
    text(details, width / 2, 570);
  }
}
