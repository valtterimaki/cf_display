// Fonts (and later images, shaders...) shared by all screens.
//
// Everything is loaded once in setup() by loadAssets(), before any screen starts.
// Loading on first use would freeze the sketch in the middle of an animation:
// the first font looked up by name took over 2 s on the Mac.
//
// Add new assets here, never load them inside a screen's draw methods.

// Processing's own default font, copied into data/ (license file next to it).
// Placeholder until real fonts are chosen: put .ttf/.otf files in data/ and change this.
final String FONT_FILE = "ProcessingSansPro-Regular.ttf";

// One font per size: text is drawn from glyph images made at the font's own
// size, so it looks sharpest at exactly that size.
PFont fontHuge;    // 96 px — the clock
PFont fontLarge;   // 64 px — big numbers
PFont fontTitle;   // 40 px — screen titles
PFont fontBody;    // 24 px — normal text
PFont fontSmall;   // 18 px — secondary text
PFont fontDebug;   // 14 px — debug overlay (monospaced)

// Character blocks (char_block.pde). A custom Iosevka build with "Term" spacing:
// every glyph is exactly one cell wide.
final String CHAR_FONT_FILE = "fonts/IosevkaCustom-Regular.ttf";
CharFont fontChar;   // 21 px — character blocks

// Colors from the Figma designs. Plain color(r, g, b) values work everywhere too.
final color BACKGROUND = #000000;   // what screens clear to; inverted Cells cut out in this
final color GREEN      = #549680;
final color YELLOW     = #DCD356;
final color RED        = #E33F5F;
final color WHITE      = #FFFFFF;

CoreVideo videoRooster;   // 538×130 logo animation, plays once

CharAnimation animSpinner;   // 4×4 pulsing square, loops

void loadAssets() {
  int startMillis = millis();

  fontHuge  = createFont(FONT_FILE, 96);
  fontLarge = createFont(FONT_FILE, 64);
  fontTitle = createFont(FONT_FILE, 40);
  fontBody  = createFont(FONT_FILE, 24);
  fontSmall = createFont(FONT_FILE, 18);

  // A font name instead of a file: Java's built-in monospaced font.
  // This is the slow one on the Mac (it scans all installed fonts), but here that
  // only makes startup a couple of seconds longer.
  fontDebug = createFont("Monospaced", 14);

  fontChar = loadCharFont(CHAR_FONT_FILE, 21);

  videoRooster = loadVideo("rooster", 50, false);
  animSpinner = loadCharAnimation("spinner", 4, true);

  println("[assets] loaded in " + (millis() - startMillis) + " ms");
}

// Videos are frame sequences in data/video/<folder>/, named <name>_<5-digit frame>,
// e.g. rooster_00000.png (.jpg, or .png for transparency/flat graphics).
// Load them in loadAssets() like the fonts. See CoreVideo.java for how screens play them.

// Every loaded video, so the debug view can show whether decoding keeps up.
ArrayList<CoreVideo> videos = new ArrayList<CoreVideo>();

CoreVideo loadVideo(String folder, float fps, boolean loop) {
  CoreVideo video = new CoreVideo(new File(dataPath("video/" + folder)), fps, loop, FRAME_RATE);
  videos.add(video);
  return video;
}
