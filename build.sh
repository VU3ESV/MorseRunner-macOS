#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Build Morse Runner for macOS (Free Pascal + Lazarus LCL, Cocoa widgetset).
#
# Prerequisites (see CLAUDE.md §4):
#   brew install fpc portaudio
#   # and a lazbuild built from Lazarus source (no sudo needed):
#   git clone --depth 1 -b lazarus_3_6 \
#       https://gitlab.com/freepascal.org/lazarus/lazarus.git ../lazarus-src
#   ( cd ../lazarus-src && make lazbuild PP="$(which fpc)" )
#
# Usage:  ./build.sh            # uses ../lazarus-src by default
#         LAZARUS_DIR=/path ./build.sh
#------------------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LAZ="${LAZARUS_DIR:-$HERE/../lazarus-src}"

if [ ! -x "$LAZ/lazbuild" ]; then
  echo "ERROR: lazbuild not found at '$LAZ/lazbuild'." >&2
  echo "Set LAZARUS_DIR or build lazbuild first (see the header of this script)." >&2
  exit 1
fi

"$LAZ/lazbuild" --lazarusdir="$LAZ" --ws=cocoa "$HERE/MorseRunner.lpi"

# lazbuild puts a symlink in the .app; replace it with a real copy so the bundle
# is self-contained and launchable via `open`.
if [ -f "$HERE/MorseRunner" ] && [ -d "$HERE/MorseRunner.app/Contents/MacOS" ]; then
  rm -f "$HERE/MorseRunner.app/Contents/MacOS/MorseRunner"
  cp "$HERE/MorseRunner" "$HERE/MorseRunner.app/Contents/MacOS/MorseRunner"
fi

# Bundle the app icon (assets/MorseRunner.icns; regenerate with assets/gen_icon.py).
ICNS="$HERE/assets/MorseRunner.icns"
PLIST="$HERE/MorseRunner.app/Contents/Info.plist"
if [ -f "$ICNS" ] && [ -f "$PLIST" ]; then
  mkdir -p "$HERE/MorseRunner.app/Contents/Resources"
  cp -f "$ICNS" "$HERE/MorseRunner.app/Contents/Resources/MorseRunner.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile MorseRunner" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string MorseRunner" "$PLIST"
  # nudge Finder/LaunchServices to pick up the new icon
  touch "$HERE/MorseRunner.app"
fi

echo
echo "Built:  $HERE/MorseRunner"
echo "Bundle: $HERE/MorseRunner.app   (run with:  open MorseRunner.app)"
