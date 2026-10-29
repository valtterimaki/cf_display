# Raspberry Pi

Step 8 of [PLAN.md](../PLAN.md). **Not done yet**: the Pi has no OS installed.

## To do

- [ ] Check which display interface the 720×720 screen uses (HDMI or DSI) and its config (timings, rotation)
- [ ] Install Raspberry Pi OS Lite 64-bit, minimal X11 (`xserver-xorg`, `xinit`), git
- [ ] Install Processing 4.5.x Linux ARM 64-bit; verify the CLI path/command on Linux
- [ ] Check the KMS GL driver (`dtoverlay=vc4-kms-v3d`) and that P2D runs on the 3B
- [ ] Write `scripts/pi-setup.md` (step-by-step install notes) and `scripts/run-pi.sh`
- [ ] Autostart: console auto-login → `~/.bash_profile` runs `startx` on tty1 → `~/.xinitrc` runs `scripts/run-pi.sh`
- [ ] `run-pi.sh`: disable screen blanking (`xset s off -dpms`), hide the mouse cursor, maybe restart the sketch if it crashes
- [ ] Update flow over SSH: `git pull` + restart sketch (script or reboot)
- [ ] Pi `data/config.json`: `"hardware": "pi"`, `"fullscreen": true`, `"debug": false`, `"fakeTime": ""`, calendar links
- [ ] Set the Pi's time zone (`raspi-config` → Localisation): calendar times are shown in the machine's local time
- [ ] Check how long the first calendar parse takes on the 3B (about 0.6 s on the Mac)
- [ ] Run the display at the same refresh rate as `FRAME_RATE`, otherwise motion is uneven
- [ ] Measure video decode time on the 3B (debug view; ~10 ms per 720×720 frame on the Mac, budget 33 ms at 30 fps). Too slow → smaller frames drawn scaled up, or more decode threads
- [ ] Measure character block draw time on the 3B (debug view "blocks … ms"; ~0.3 ms for the 42×21 demo on the Mac)
- [ ] Measure FPS with the debug view; later test the CRT shader's performance on the 3B
- [ ] Choose GPIO library (Pi4J / processing.io / other) and implement `HwPi` (buttons, encoder, LEDs, light sensor via ADC or I²C)
- [ ] If commits are ever made on the Pi: `scripts/check.sh` needs `PROCESSING=<path>` there
