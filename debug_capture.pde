// Capture mode: screenshots for checking changes, without editing code.
// config.json "capture": [350, 500] saves those frames as capture/frame_0350.png etc.
// (git-ignored), then quits the sketch. [] = off.

int[] captureFrames = new int[0];

void loadCaptureFrames() {
  JSONArray frames = config.getArray("capture");
  captureFrames = new int[frames.size()];
  for (int i = 0; i < frames.size(); i++) captureFrames[i] = frames.getInt(i);
  if (captureFrames.length > 0) println("[capture] frames " + join(str(captureFrames), ", ") + ", then quit");
}

/** At the end of draw(), so a capture shows everything drawn that frame. */
void captureUpdate() {
  if (captureFrames.length == 0) return;
  for (int frame : captureFrames) {
    if (frameCount == frame) saveFrame("capture/frame_####.png");
  }
  // saveFrame() writes in the background: give it a second before quitting
  if (frameCount == max(captureFrames) + FRAME_RATE) exit();
}
