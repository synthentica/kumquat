#!/usr/bin/env bash
# Builds a universal Kumquat.app into build/ and zips it.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP="build/Kumquat.app"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Kumquat" "$APP/Contents/MacOS/Kumquat"
# FFmpeg for the formats macOS can't encode (MP3, OGG, Opus, WMA, WebM, MKV, AVI, WMV, WebP).
# Built by scripts/build-ffmpeg.sh; the app also runs without it, with fewer formats.
if [ -x .ffmpeg/bin/ffmpeg ]; then
  cp .ffmpeg/bin/ffmpeg "$APP/Contents/MacOS/ffmpeg"
else
  echo "warning: .ffmpeg/bin/ffmpeg not found, building without FFmpeg (run scripts/build-ffmpeg.sh)" >&2
fi
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

# App icon, drawn in code so there are no binary assets to keep in sync.
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
swift scripts/make-icon.swift "build/icon-1024.png"
for size in 16 32 128 256 512; do
  sips -z $size $size build/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double build/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Kumquat.zip
echo "Built $APP ($VERSION, build $BUILD)"
