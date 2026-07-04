#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Build + package a self-contained MorseRunner.app (via package.sh) and install
# it to /Applications. Run ./build.sh's prerequisites first (see build.sh).
#------------------------------------------------------------------------------
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

"$HERE/package.sh"

rm -rf /Applications/MorseRunner.app
cp -R "$HERE/MorseRunner.app" /Applications/MorseRunner.app

echo "Installed: /Applications/MorseRunner.app"
otool -L /Applications/MorseRunner.app/Contents/MacOS/MorseRunner | grep -i portaudio || true
