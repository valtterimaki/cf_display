// Stand-in for a screen whose content isn't designed yet: its name and what will be there.
// Used for several screens; each registration passes its own text and length.

class ScreenPlaceholder extends CoreScreen {

  final String title;
  final String note;
  final float mainLength;

  ScreenPlaceholder(String title, String note, float mainLength) {
    this.title = title;
    this.note = note;
    this.mainLength = mainLength;
  }

  void drawIntro() {
    nextPhase();
  }

  void drawMain() {
    drawPlaceholder(title, note);
    if (tl.t() >= mainLength) nextPhase();
  }

  void drawOutro() {
    nextPhase();
  }
}

/** A placeholder screen's look, shared with the other unfinished screens. */
void drawPlaceholder(String title, String note) {
  background(BACKGROUND);
  noStroke();
  textAlign(CENTER, CENTER);
  fill(WHITE);
  textFont(fontTitle);
  text(title, width / 2, height / 2 - 30);
  fill(GRAY);
  textFont(fontBody);
  text(note, 60, height / 2 + 10, width - 120, 120);
  textFont(fontSmall);
  text("placeholder", width / 2, height - 40);
}
