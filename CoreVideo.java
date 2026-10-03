import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.io.File;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import javax.imageio.ImageIO;
import javax.imageio.ImageReadParam;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;

import processing.core.PImage;

/**
 * A video stored as numbered image files (a frame sequence), for example
 * data/video/intro/0001.jpg, 0002.jpg, ... (JPG or PNG, PNG for transparency).
 *
 * Screens draw it like any image, at any size and with any effect:
 *
 *   image(video.frame(tl.t()), 0, 0);
 *   if (tl.t() >= video.duration()) nextPhase();
 *
 * Why it plays smoothly:
 * - A background thread decodes frames a little ahead of the one on screen.
 *   The draw thread never reads or decodes files.
 * - frame() always returns the same PImage, so the GPU keeps one texture and only
 *   updates its pixels.
 * - Pixel arrays are reused. A new 2 MB image every frame would make Java's garbage
 *   collector pause now and then, which shows as stutter.
 *
 * Videos are shared assets (loadVideo() in ui_assets.pde), so the decoder works
 * ahead even before a screen shows the video. After the last frame it decodes the
 * first frames again, so the next showing starts right away.
 *
 * Play forward. A jump elsewhere works, but the first frame after it comes late.
 */
public class CoreVideo {

  // Decoded frames kept ready ahead of the one on screen.
  // ponytail: every video keeps (BUFFER_FRAMES + 2) frames in memory all the time
  // (about 16 MB for 720×720). Free them while a video isn't shown if memory runs low.
  private static final int BUFFER_FRAMES = 6;

  // Moves video frame changes halfway between two draws (at 60 fps). Without it, a
  // 30 fps video changes frame exactly on draw frames, and a millisecond of timing
  // jitter shows some frames once and others three times.
  private static final float HALF_DRAW_FRAME = 0.5f / 60;

  private final String name;
  private final File[] files;
  private final float fps;
  private final boolean loop;
  private final int width;
  private final int height;

  /** What screens draw. Its pixel array is swapped for each new frame. */
  private final PImage image;

  // Shared with the decode thread. Only used while holding the lock (`this`).
  private final Map<Integer, int[]> decoded = new HashMap<>();   // frame index → pixels
  private final ArrayDeque<int[]> spareArrays = new ArrayDeque<>();
  private int wanted = 0;    // frame the screen asked for last
  private int shown = -1;    // frame currently in `image`

  // Decode thread only. Reused for every frame.
  private BufferedImage decodeTarget = null;

  // For the debug view
  private volatile float decodeMillis = 0;   // average time to decode one frame
  private int lateFrames = 0;                // draws where the wanted frame wasn't ready

  /** Reads the frame list and size, and starts decoding the first frames. */
  public CoreVideo(File folder, float fps, boolean loop) {
    this.name = folder.getName();
    this.fps = fps;
    this.loop = loop;

    File[] found = folder.listFiles((dir, file) -> file.toLowerCase().matches(".*\\.(png|jpe?g)"));
    if (found == null || found.length == 0) {
      throw new IllegalArgumentException("No .png/.jpg frames in " + folder.getPath());
    }
    Arrays.sort(found);   // by file name, so number the frames with leading zeros
    files = found;

    BufferedImage first = readImage(files[0]);
    width = first.getWidth();
    height = first.getHeight();
    image = new PImage(width, height, PImage.ARGB);

    Thread thread = new Thread(this::decodeLoop, "video-" + name);
    thread.setDaemon(true);   // don't keep the program alive on exit
    thread.start();

    System.out.println("[video] " + name + ": " + files.length + " frames, "
      + width + "x" + height + ", " + fps + " fps" + (loop ? ", loops" : ""));
  }

  // --- used by screens (draw thread) ---

  /**
   * The frame to show `seconds` into the video. Returns the same PImage every time.
   * If the decoder hasn't kept up, the previous frame stays on screen.
   */
  public PImage frame(float seconds) {
    int index = indexAt(seconds);
    if (index == shown) return image;

    synchronized (this) {
      wanted = index;
      int[] pixels = decoded.remove(index);
      if (pixels != null) {
        spareArrays.add(image.pixels);
        image.pixels = pixels;
        image.updatePixels();   // tells the renderer to upload the new pixels
        shown = index;
      } else {
        lateFrames++;
      }
      notifyAll();   // wake the decoder: the window of wanted frames moved
    }
    return image;
  }

  /** Length in seconds. */
  public float duration() {
    return files.length / fps;
  }

  public int width() {
    return width;
  }

  public int height() {
    return height;
  }

  // --- info for the debug view ---

  public String name() {
    return name;
  }

  public float fps() {
    return fps;
  }

  public float decodeMillis() {
    return decodeMillis;
  }

  public int lateFrames() {
    return lateFrames;
  }

  // --- internals ---

  private int indexAt(float seconds) {
    int index = (int) Math.floor((seconds + HALF_DRAW_FRAME) * fps);
    if (index < 0) return 0;
    if (loop) return index % files.length;
    return Math.min(index, files.length - 1);
  }

  // ponytail: one decode thread. If the Pi can't decode fast enough (decode time
  // over 1000 / fps ms), use smaller frames scaled up when drawn, or add threads.
  private void decodeLoop() {
    while (true) {
      int index;
      int[] pixels;
      synchronized (this) {
        while ((index = nextToDecode()) < 0) {
          try {
            wait();
          } catch (InterruptedException e) {
            return;
          }
        }
        pixels = spareArrays.isEmpty() ? new int[width * height] : spareArrays.poll();
      }

      long start = System.nanoTime();
      try {
        decodeInto(files[index], pixels);
      } catch (Exception e) {
        System.out.println("[video] ERROR " + name + "/" + files[index].getName() + ": " + e.getMessage());
        Arrays.fill(pixels, 0);   // show it as a transparent frame, keep playing
      }
      float millis = (System.nanoTime() - start) / 1e6f;
      decodeMillis += (millis - decodeMillis) * 0.1f;   // smoothed, so the debug view is readable

      synchronized (this) {
        if (isInWindow(index)) {
          decoded.put(index, pixels);
        } else {
          spareArrays.add(pixels);   // playback already moved past it
        }
      }
    }
  }

  /**
   * The first frame of the window (the BUFFER_FRAMES frames from `wanted` on) that
   * isn't decoded yet, or -1 if all are. Recycles frames playback has moved past.
   * Call with the lock held.
   */
  private int nextToDecode() {
    Iterator<Map.Entry<Integer, int[]>> it = decoded.entrySet().iterator();
    while (it.hasNext()) {
      Map.Entry<Integer, int[]> entry = it.next();
      if (!isInWindow(entry.getKey())) {
        spareArrays.add(entry.getValue());
        it.remove();
      }
    }

    // The window wraps to the start: a loop continues, and a video that played
    // to the end has its first frames ready for the next time it's shown.
    for (int i = 0; i < BUFFER_FRAMES; i++) {
      int index = (wanted + i) % files.length;
      if (index != shown && !decoded.containsKey(index)) return index;
    }
    return -1;
  }

  private boolean isInWindow(int index) {
    int ahead = (index - wanted + files.length) % files.length;
    return ahead < BUFFER_FRAMES;
  }

  /** Decodes an image file into ARGB pixels (Processing's format). */
  private void decodeInto(File file, int[] pixels) throws Exception {
    if (decodeTarget == null) {
      decodeTarget = readImage(file);   // first frame: let ImageIO pick the image type
    } else {
      readImage(file, decodeTarget);    // others: decode into the same image again
    }
    BufferedImage img = decodeTarget;

    // Copy straight from the raw bytes for the usual types; getRGB() is slow
    if (img.getType() == BufferedImage.TYPE_3BYTE_BGR) {          // JPG, PNG without alpha
      byte[] b = ((DataBufferByte) img.getRaster().getDataBuffer()).getData();
      for (int i = 0, j = 0; i < pixels.length; i++, j += 3) {
        pixels[i] = 0xFF000000 | (b[j + 2] & 0xFF) << 16 | (b[j + 1] & 0xFF) << 8 | (b[j] & 0xFF);
      }
    } else if (img.getType() == BufferedImage.TYPE_4BYTE_ABGR) {  // PNG with alpha
      byte[] b = ((DataBufferByte) img.getRaster().getDataBuffer()).getData();
      for (int i = 0, j = 0; i < pixels.length; i++, j += 4) {
        pixels[i] = (b[j] & 0xFF) << 24 | (b[j + 3] & 0xFF) << 16 | (b[j + 2] & 0xFF) << 8 | (b[j + 1] & 0xFF);
      }
    } else {
      img.getRGB(0, 0, width, height, pixels, 0, width);   // anything else (grayscale, palette...)
    }
  }

  private static BufferedImage readImage(File file) {
    try {
      return readImage(file, null);
    } catch (Exception e) {
      throw new IllegalArgumentException("Can't read video frame " + file.getPath() + ": " + e.getMessage());
    }
  }

  /** Reads an image file, into `target` if given (must be the same size and type). */
  private static BufferedImage readImage(File file, BufferedImage target) throws Exception {
    try (ImageInputStream input = ImageIO.createImageInputStream(file)) {
      Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
      if (!readers.hasNext()) throw new Exception("not an image");
      ImageReader reader = readers.next();
      try {
        reader.setInput(input, true, true);
        ImageReadParam param = reader.getDefaultReadParam();
        param.setDestination(target);
        return reader.read(0, param);
      } finally {
        reader.dispose();
      }
    }
  }
}
