// Debug view, toggled with the TOGGLE_DEBUG action (D key in simulation).
// Drawn last, on top of everything. Shows performance, scheduler state,
// hardware state and data source status.
//
// Usage in draw():
//   debugBeginFrame();
//   ...all normal drawing...
//   debugEndFrame();
//   if (debugVisible) drawDebugOverlay();

final int DEBUG_HISTORY = 120;                        // frames of draw-time history
float[] debugDrawTimes = new float[DEBUG_HISTORY];    // ms per frame
int debugHistoryIndex = 0;
long debugFrameStartNanos = 0;

void debugBeginFrame() {
  debugFrameStartNanos = System.nanoTime();
}

void debugEndFrame() {
  float ms = (System.nanoTime() - debugFrameStartNanos) / 1e6;
  debugDrawTimes[debugHistoryIndex] = ms;
  debugHistoryIndex = (debugHistoryIndex + 1) % DEBUG_HISTORY;
}

void drawDebugOverlay() {
  pushStyle();   // don't leak font/colours/modes into the screens
  textFont(fontDebug);   // loaded in ui_assets.pde
  textAlign(LEFT, TOP);
  rectMode(CORNER);

  float x = 12;
  float y = 12;
  float lineHeight = 18;
  float panelWidth = width - 24;

  String[] lines = {
    debugPerformanceLine(),
    debugScreenLine(),
    debugQueueLine(),
    debugHardwareLine(),
  };
  String[] sourceLines = concat(debugSourceLines(), debugVideoLines());

  int lineCount = lines.length + sourceLines.length;
  float panelHeight = lineCount * lineHeight + 16 + 40;   // + graph

  noStroke();
  fill(0, 180);
  rect(x - 6, y - 6, panelWidth + 12, panelHeight, 6);

  fill(120, 255, 140);
  for (String line : lines) {
    text(line, x, y);
    y += lineHeight;
  }
  // LEDs at the right end of the HW line (the last of `lines`)
  drawDebugLeds(x + panelWidth - 60, y - lineHeight + 8);

  for (String line : sourceLines) {
    fill(line.contains("ERROR") ? color(255, 120, 100) : color(120, 255, 140));
    text(line, x, y);
    y += lineHeight;
  }

  drawDebugGraph(x, y + 8, panelWidth, 32);

  popStyle();
}

// --- lines ---

String debugPerformanceLine() {
  float max = 0;
  float sum = 0;
  for (float t : debugDrawTimes) {
    max = max(max, t);
    sum += t;
  }
  return "FPS " + fmtDecimal(frameRate, 1)
    + "   draw " + fmtDecimal(sum / DEBUG_HISTORY, 1) + " ms"
    + " (max " + fmtDecimal(max, 1) + ")";
}

String debugScreenLine() {
  if (scheduler.isInTransition()) {
    return "SCREEN transition  " + scheduler.currentId() + " -> " + scheduler.nextId();
  }
  CoreScreen screen = scheduler.currentScreen();
  if (screen == null) return "SCREEN none";
  return "SCREEN " + scheduler.currentId()
    + "  " + screen.phase()
    + "  " + fmtDecimal(screen.phaseTime(), 1) + " s";
}

String debugQueueLine() {
  java.util.List<String> queued = scheduler.queuedIds();
  return "QUEUE  " + (queued.isEmpty() ? "(empty)" : String.join(", ", queued));
}

String debugHardwareLine() {
  return "HW     " + hardware.name()
    + "   light " + fmtDecimal(hardware.lightLevel(), 2);
}

String[] debugSourceLines() {
  java.util.List<DataSource> sources = store.sources();
  String[] lines = new String[sources.size()];
  for (int i = 0; i < sources.size(); i++) {
    DataSource s = sources.get(i);
    String line = "DATA   " + s.name() + "  " + s.status();
    float age = s.secondsSinceUpdate();
    if (age >= 0) line += "  " + round(age) + " s ago";
    if (s.lastError() != null) line += "  (" + s.lastError() + ")";
    lines[i] = line;
  }
  return lines;
}

/** Decoding keeps up while its time stays under the budget (time per video frame). */
String[] debugVideoLines() {
  String[] lines = new String[videos.size()];
  for (int i = 0; i < videos.size(); i++) {
    CoreVideo v = videos.get(i);
    lines[i] = "VIDEO  " + v.name()
      + "  decode " + fmtDecimal(v.decodeMillis(), 1) + " ms"
      + " (budget " + fmtDecimal(1000 / v.fps(), 1) + ")"
      + "  late " + v.lateFrames();
  }
  return lines;
}

// --- graphics ---

/** LEDs as circles; brightness = fill. */
void drawDebugLeds(float x, float y) {
  for (int i = 0; i < hardware.ledCount(); i++) {
    float b = hardware.getLed(i);
    stroke(120, 255, 140);
    strokeWeight(1);
    fill(255, 60, 40, 40 + b * 215);
    ellipse(x + i * 22, y, 14, 14);
  }
  noStroke();
}

/** Draw time per frame. The line marks 16.7 ms (the 60 fps budget). */
void drawDebugGraph(float x, float y, float w, float h) {
  float maxMs = 33.3;
  float budgetY = y + h - h * (16.7 / maxMs);

  stroke(255, 255, 255, 60);
  strokeWeight(1);
  line(x, budgetY, x + w, budgetY);

  noStroke();
  float barWidth = w / DEBUG_HISTORY;
  for (int i = 0; i < DEBUG_HISTORY; i++) {
    // oldest on the left
    float ms = debugDrawTimes[(debugHistoryIndex + i) % DEBUG_HISTORY];
    float barHeight = min(h, h * ms / maxMs);
    fill(ms > 16.7 ? color(255, 120, 100) : color(120, 255, 140));
    rect(x + i * barWidth, y + h - barHeight, max(1, barWidth - 1), barHeight);
  }
}
