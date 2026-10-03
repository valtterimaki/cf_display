// Plays the rooster logo animation (a video, see CoreVideo.java) once, centered.
// Intro: nothing to animate, the video starts right away. Outro: the last frame fades out.

class ScreenRooster extends CoreScreen {

  final float HOLD_LENGTH = 1.0;    // last frame stays this long after the video ends
  final float OUTRO_LENGTH = 0.6;

  void drawIntro() {
    drawVideo(0, 255);
    nextPhase();
  }

  void drawMain() {
    drawVideo(tl.t(), 255);
    if (tl.t() >= videoRooster.duration() + HOLD_LENGTH) nextPhase();
  }

  void drawOutro() {
    float fade = CoreEase.inCubic(tl.progress(0, OUTRO_LENGTH));
    drawVideo(videoRooster.duration(), 255 * (1 - fade));   // keeps showing the last frame
    if (tl.t() >= OUTRO_LENGTH) nextPhase();
  }

  void drawVideo(float seconds, float alpha) {
    background(0);   // the video's own background is black too
    imageMode(CENTER);
    tint(255, alpha);
    image(videoRooster.frame(seconds), width / 2, height / 2);
    noTint();
    imageMode(CORNER);
  }
}
