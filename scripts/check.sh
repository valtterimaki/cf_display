#!/usr/bin/env bash
# Checks the sketch before a commit: the mechanical rules hold, and it builds.
# Run by hand: scripts/check.sh
# As a pre-commit hook (once per clone): git config core.hooksPath scripts/hooks
# Processing found somewhere unusual: PROCESSING=/path/to/Processing scripts/check.sh
# Checks the files on disk, not only what's staged.

cd "$(dirname "$0")/.." || exit 1
failed=0

# Each rule: files that break it are printed with line numbers
if grep -n "LocalDateTime\.now()\|LocalDate\.now()" *.java *.pde | grep -v "^CoreClock\.java:"; then
  echo "[check] Date/time read outside CoreClock: use CoreClock.now() / CoreClock.today(), so \"fakeTime\" works"
  failed=1
fi
if grep -n "saveFrame(\|exit()" *.java *.pde | grep -v "^debug_capture\.pde:"; then
  echo "[check] Leftover screenshot code: use config \"capture\" for screenshots"
  failed=1
fi
if grep -n "textSize(" screen_*.pde; then
  echo "[check] textSize() in a screen: load a PFont per size in loadAssets() and use textFont()"
  failed=1
fi
if grep -n "^  public " screen_*.pde; then
  echo "[check] public method in a screen: screen methods are package-private, without public"
  failed=1
fi

# The build: macOS, Windows (Git Bash), or Processing on the PATH
if [ -z "$PROCESSING" ]; then
  for candidate in "/Applications/Processing.app/Contents/MacOS/Processing" \
                   "/c/Program Files/Processing/Processing.exe" \
                   "$(command -v Processing)"; do
    if [ -x "$candidate" ]; then PROCESSING="$candidate"; break; fi
  done
fi
if [ -z "$PROCESSING" ]; then
  echo "[check] Processing not found: set PROCESSING=/path/to/Processing"
  exit 1
fi
sketch="$(pwd -W 2>/dev/null || pwd)"   # Windows wants C:/... instead of /c/...
if ! output="$("$PROCESSING" cli --sketch="$sketch" --build 2>&1)"; then
  echo "$output" | grep -v "AWT\|display count\|writable\|X11"
  echo "[check] Build failed"
  failed=1
fi

if [ "$failed" -eq 0 ]; then echo "[check] ok"; fi
exit "$failed"
