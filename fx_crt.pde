// CRT effect: the finished frame goes through an analogue TV signal and back
// (data/shaders/crt.frag), plus the hidden panel to tune it (C key). See docs/crt.md.
//
// Usage in draw(), after the screens and before the debug overlay:
//   drawCrt();
//   ...debug overlay...
//   drawCrtPanel();

CoreCrt crt;
String[] crtFragSource;     // crt.frag as loaded, without the TAPS/PAL defines
PShader crtShader;
int crtShaderTaps = -1;     // what crtShader was compiled with
boolean crtShaderPal;
boolean crtUniformsDirty = true;   // settings changed: send them to the shader again
float[] crtChromaWeights;
float[] crtLumaWeights;

boolean crtPanelOpen = false;
int crtPanelRow = 0;
boolean crtUnsaved = false;

/** In loadAssets(). */
void loadCrt() {
  crt = new CoreCrt(new File(dataPath("crt.json")));
  crtFragSource = loadStrings("shaders/crt.frag");
}

/** Runs the effect over everything drawn so far this frame. */
void drawCrt() {
  if (!crt.isOn()) return;

  // TAPS and PAL are loop bounds and #if branches in the shader, so a change compiles it
  // again (a few ms, only when they change in the panel)
  if (crt.tapCount() != crtShaderTaps || crt.isPal() != crtShaderPal) compileCrtShader();

  if (crtUniformsDirty) {
    setCrtUniforms();
    crtUniformsDirty = false;
  }
  // Every frame: these change each frame. The rest stay set in the shader program.
  crtShader.set("phaseFrame", (float) (frameCount % 4));
  crtShader.set("noiseSeed", (float) (frameCount % 1000));

  filter(crtShader);
}

void compileCrtShader() {
  crtShaderTaps = crt.tapCount();
  crtShaderPal = crt.isPal();
  String[] defines = {
    "#define TAPS " + crtShaderTaps,
    "#define PAL " + (crtShaderPal ? 1 : 0)
  };
  // Through a temp file because only loadShader() translates GLSL ES 1.00 for the
  // desktop's OpenGL. Only at startup and when TAPS/PAL change in the panel.
  File file = new File(System.getProperty("java.io.tmpdir"), "cf_display_crt.frag");
  saveStrings(file.getAbsolutePath(), concat(defines, crtFragSource));
  crtShader = loadShader(file.getAbsolutePath());
  // Exactly 2 * TAPS + 1 values: the shader's arrays are that size
  crtChromaWeights = new float[2 * crtShaderTaps + 1];
  crtLumaWeights = new float[2 * crtShaderTaps + 1];
  crtUniformsDirty = true;
  println("[crt] shader for " + crtShaderTaps + " taps, " + (crtShaderPal ? "PAL" : "NTSC")
          + ": " + (2 * crtShaderTaps + 1) + " reads per pixel");
}

void setCrtUniforms() {
  crt.chromaWeights(crtChromaWeights);
  crt.lumaWeights(crtLumaWeights);

  crtShader.set("resolution", (float) pixelWidth, (float) pixelHeight);   // real pixels, also on a Retina Mac
  crtShader.set("chromaWeight", crtChromaWeights);
  crtShader.set("chromaSumEven", crt.weightSum(crtChromaWeights, 0));
  crtShader.set("chromaSumOdd", crt.weightSum(crtChromaWeights, 1));
  crtShader.set("lumaWeight", crtLumaWeights);
  crtShader.set("chromaDelay", crt.chromaDelay.value);
  crtShader.set("chromaGain", crt.chromaGain.value);
  float hue = radians(crt.hue.value);
  crtShader.set("hueRotation", cos(hue), sin(hue));
  crtShader.set("nonlin", crt.nonlin.value);
  crtShader.set("clipHi", crt.clipHi.value);
  crtShader.set("noise", crt.noise.value);
}

// --- panel ---
// A dev tool, so it reads the keyboard directly instead of going through HwAction:
// it works the same with a USB keyboard on the Pi, whatever "hardware" is set to.

/** From keyPressed(). Returns true if the panel used the key. */
boolean crtPanelKey(char k, int code) {
  if (k == 'c' || k == 'C') {
    crtPanelOpen = !crtPanelOpen;
    return true;
  }
  if (!crtPanelOpen) return false;

  CoreCrt.Setting selected = crt.all.get(crtPanelRow);
  if (k == CODED && code == UP) {
    crtPanelRow = (crtPanelRow + crt.all.size() - 1) % crt.all.size();
  } else if (k == CODED && code == DOWN) {
    crtPanelRow = (crtPanelRow + 1) % crt.all.size();
  } else if (k == CODED && (code == LEFT || code == RIGHT)) {
    crt.change(selected, code == RIGHT ? 1 : -1);
    crtSettingsChanged();
  } else if (k == 'r' || k == 'R') {
    crt.reset(selected);
    crtSettingsChanged();
  } else if (k == 's' || k == 'S') {
    crt.save();   // a tiny file, only on a key press: fine on the draw thread
    crtUnsaved = false;
  } else {
    return false;   // other keys still work, e.g. number keys to look at other screens
  }
  return true;
}

void crtSettingsChanged() {
  crtUniformsDirty = true;
  crtUnsaved = true;
}

void drawCrtPanel() {
  if (!crtPanelOpen) return;
  pushStyle();
  textFont(fontDebug);
  textAlign(LEFT, TOP);
  rectMode(CORNER);

  float lineHeight = 18;
  float x = 18;
  float panelHeight = (crt.all.size() + 4) * lineHeight + 12;
  float y = height - panelHeight - 12;

  noStroke();
  fill(0, 200);
  rect(x - 6, y - 6, 510, panelHeight, 6);

  fill(120, 255, 140);
  text("CRT  " + (2 * crt.tapCount() + 1) + " reads/px" + (crtUnsaved ? "  * unsaved" : ""), x, y);
  y += lineHeight * 1.5;

  for (int i = 0; i < crt.all.size(); i++) {
    CoreCrt.Setting s = crt.all.get(i);
    fill(i == crtPanelRow ? color(255, 255, 140) : color(120, 255, 140));
    text((i == crtPanelRow ? "> " : "  ") + s.key, x, y);
    text(crtValueText(s), x + 170, y);
    y += lineHeight;
  }

  fill(200);
  text(crt.all.get(crtPanelRow).help, x, y + lineHeight * 0.5);
  text("Up/Down select  Left/Right change  R default  S save  C close", x, y + lineHeight * 1.5);
  popStyle();
}

String crtValueText(CoreCrt.Setting s) {
  if (s.isOnOff()) return s.value > 0.5 ? "on" : "off";
  String text = fmtDecimal(s.value, crtDecimals(s.step)) + " " + s.unit;
  if (crt.maxOf(s) < s.max) text += "  (max " + fmtDecimal(crt.maxOf(s), crtDecimals(s.step)) + ")";
  return text;
}

/** Decimals needed to show a value in these steps: 1 → 0, 0.25 → 2, 0.002 → 3. */
int crtDecimals(float step) {
  int d = 0;
  while (d < 4 && abs(step * pow(10, d) - round(step * pow(10, d))) > 0.0001) d++;
  return d;
}
