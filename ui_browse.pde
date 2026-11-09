// The layer shown while browsing screens with the knob (CoreTriggers.browse).
// Drawn on top of whatever screen is showing. Placeholder look until designed.

void drawBrowseLayer() {
  String selected = triggers.browseSelection();
  if (selected == null) return;

  pushStyle();
  noStroke();
  fill(BACKGROUND);
  rect(width - 260, 20, 240, 56, 8);
  fill(WHITE);
  textAlign(CENTER, CENTER);
  textFont(fontBody);
  text("> " + selected, width - 140, 48);
  popStyle();
}
