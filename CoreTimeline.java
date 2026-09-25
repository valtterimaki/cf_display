/**
 * A stopwatch for animations. All times are in seconds.
 *
 * Call update(now) once per frame, then ask questions about time:
 *
 *   float x = tl.progress(0.5f, 1.2f);  // 0..1 from 0.5 s to 1.7 s
 *   if (tl.once(2.0f)) { ... }          // true on the one frame that passes 2.0 s
 *   if (tl.between(1, 3)) { ... }       // true while 1 s <= t < 3 s
 *   if (tl.every(0.5f)) { ... }         // true once every 0.5 s
 *
 * The timeline does not read the clock itself — the sketch passes the time in.
 * That keeps it independent of Processing and lets time be paused or scaled later.
 */
public class CoreTimeline {

  private float startTime = 0;
  private float t = 0;          // seconds since start, this frame
  private float prevT = 0;      // seconds since start, previous frame

  public CoreTimeline(float now) {
    restart(now);
  }

  /** Start counting from zero again. */
  public void restart(float now) {
    startTime = now;
    t = 0;
    prevT = Float.NEGATIVE_INFINITY;  // so once(0) fires on the first frame
  }

  /** Call once per frame with the current time in seconds. */
  public void update(float now) {
    prevT = t;
    t = now - startTime;
  }

  /** Seconds since start. */
  public float t() {
    return t;
  }

  /** 0..1 over the window [start, start + duration], clamped. */
  public float progress(float start, float duration) {
    if (duration <= 0) return t >= start ? 1 : 0;
    float p = (t - start) / duration;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  /** True exactly once: on the frame when time passes the given mark. */
  public boolean once(float at) {
    return prevT < at && t >= at;
  }

  /** True while start <= t < end. */
  public boolean between(float start, float end) {
    return t >= start && t < end;
  }

  /** True once every `interval` seconds (at interval, 2 * interval, ...). */
  public boolean every(float interval) {
    if (interval <= 0 || t <= 0) return false;
    if (prevT < 0) return false;
    return Math.floor(t / interval) > Math.floor(prevT / interval);
  }
}
