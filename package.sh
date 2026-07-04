#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Build + package a self-contained, ad-hoc-signed MorseRunner.app and zip it
# into dist/. Used by CI and by deploy.sh. Does NOT touch /Applications.
#
#   ./build.sh        must be runnable (needs fpc + a lazbuild; see build.sh)
#   output:           dist/MorseRunner-macos-<arch>.zip
#------------------------------------------------------------------------------
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/MorseRunner.app"
EXE="$APP/Contents/MacOS/MorseRunner"
ARCH="$(uname -m)"
ZIP="$HERE/dist/MorseRunner-macos-${ARCH}.zip"

# 1. compile + bundle (build.sh copies the real binary + icon into the .app)
"$HERE/build.sh"
[ -x "$EXE" ] || { echo "no executable in bundle after build"; exit 1; }

# 2. embed libportaudio and rewrite its load path so the app is self-contained
PA_SRC="$(otool -L "$EXE" | awk '/portaudio/{print $1; exit}')"
if [ -n "$PA_SRC" ] && [[ "$PA_SRC" != @executable_path/* ]]; then
  mkdir -p "$APP/Contents/Frameworks"
  cp -L "$PA_SRC" "$APP/Contents/Frameworks/libportaudio.2.dylib"
  chmod u+w "$APP/Contents/Frameworks/libportaudio.2.dylib"
  install_name_tool -id @executable_path/../Frameworks/libportaudio.2.dylib \
    "$APP/Contents/Frameworks/libportaudio.2.dylib"
  install_name_tool -change "$PA_SRC" \
    @executable_path/../Frameworks/libportaudio.2.dylib "$EXE"
fi

# 3. bundle the readme (the app opens it from next to the executable)
cp -f "$HERE/readme.txt" "$APP/Contents/MacOS/readme.txt" 2>/dev/null || true

# 4. ad-hoc sign (dylib first, then the whole bundle) — unnotarized; see RN
codesign --force --sign - "$APP/Contents/Frameworks/libportaudio.2.dylib" 2>/dev/null || true
codesign --force --deep --sign - "$APP"

# 5. zip the .app (ditto preserves the bundle + signature)
mkdir -p "$HERE/dist"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "packaged: $ZIP"

# 6. build a drag-install .dmg (the .app + an /Applications symlink). Headless-
#    friendly (hdiutil only, no Finder), so it works in CI.
DMG="$HERE/dist/MorseRunner-macos-${ARCH}.dmg"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/MorseRunner.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Morse Runner" -srcfolder "$STAGE" -ov -quiet -format UDZO "$DMG"
rm -rf "$STAGE"
echo "packaged: $DMG"

codesign -dv "$APP" 2>&1 | grep -E 'Signature|Identifier' || true
