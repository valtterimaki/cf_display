# Video

- Videos are frame sequences in `data/video/<name>/`, files named
  `<name>_<5-digit frame number>` (`rooster_00000.png`, from After Effects): `.jpg` for
  footage, `.png` for transparency or flat graphics. Played by `CoreVideo`, not the
  Processing video library (GStreamer): it was unreliable on the Pi in an earlier project.
- Load in `loadAssets()` with `loadVideo(name, fps, loop)`; screens draw
  `image(video.frame(seconds), x, y, w, h)`: any size, tint or shader.
- A background thread decodes a few frames ahead into reused arrays. Debug view shows per
  video: average decode time vs. budget (1000 / fps ms) and late frames.
- A video's own fps (`loadVideo`) is its render rate, separate from `FRAME_RATE`.
- Frame export: `ffmpeg -i in.mov -vf scale=720:720 -q:v 3 data/video/<name>/<name>_%05d.jpg`
  (PNG with alpha: `-pix_fmt rgba .../<name>_%05d.png`).
