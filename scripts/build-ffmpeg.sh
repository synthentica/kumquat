#!/usr/bin/env bash
# Builds the FFmpeg that ships inside Kumquat.app: a universal, self-contained binary under the LGPL
# (no GPL parts), with MP3, Opus, Vorbis, VP8/VP9 and WebP encoders and Apple's hardware
# VideoToolbox encoders for H.264 and HEVC. Output: .ffmpeg/bin/ffmpeg, which scripts/bundle.sh copies into the app.
#
# Needs: Xcode command line tools, nasm (`brew install nasm`). Takes a while the first time; CI caches it.
set -euo pipefail
cd "$(dirname "$0")/.."

FFMPEG=7.1
LAME=3.100
OPUS=1.5.2
OGG=1.3.5
VORBIS=1.3.7
VPX=1.14.1
WEBP=1.4.0
MIN_MACOS=13.0

ROOT="$PWD/.ffmpeg/work"
OUT="$PWD/.ffmpeg/bin"
JOBS="$(sysctl -n hw.ncpu)"
mkdir -p "$ROOT/src" "$OUT"

fetch() { # url, folder name
  local archive="$ROOT/src/$(basename "$1")"
  [ -f "$archive" ] || curl -fsSL --retry 3 -o "$archive" "$1"
  echo "$archive"
}

LAME_TGZ=$(fetch "https://downloads.sourceforge.net/project/lame/lame/$LAME/lame-$LAME.tar.gz")
OPUS_TGZ=$(fetch "https://downloads.xiph.org/releases/opus/opus-$OPUS.tar.gz")
OGG_TGZ=$(fetch "https://downloads.xiph.org/releases/ogg/libogg-$OGG.tar.gz")
VORBIS_TGZ=$(fetch "https://downloads.xiph.org/releases/vorbis/libvorbis-$VORBIS.tar.gz")
VPX_TGZ=$(fetch "https://github.com/webmproject/libvpx/archive/refs/tags/v$VPX.tar.gz")
WEBP_TGZ=$(fetch "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$WEBP.tar.gz")
FFMPEG_TXZ=$(fetch "https://ffmpeg.org/releases/ffmpeg-$FFMPEG.tar.xz")

build_arch() {
  local arch=$1
  local prefix="$ROOT/$arch/prefix"
  local work="$ROOT/$arch/work"
  local host vpx_target
  if [ "$arch" = arm64 ]; then host=aarch64-apple-darwin; vpx_target=arm64-darwin20-gcc; else host=x86_64-apple-darwin; vpx_target=x86_64-darwin20-gcc; fi
  rm -rf "$work" && mkdir -p "$work" "$prefix"
  export CC="clang -arch $arch" CXX="clang++ -arch $arch"
  export CFLAGS="-arch $arch -mmacosx-version-min=$MIN_MACOS -O2" CXXFLAGS="-arch $arch -mmacosx-version-min=$MIN_MACOS -O2"
  export LDFLAGS="-arch $arch -mmacosx-version-min=$MIN_MACOS"
  # Only our own static libraries, never Homebrew's.
  export PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig" PKG_CONFIG_PATH="$prefix/lib/pkgconfig"
  local common=(--prefix="$prefix" --host="$host" --enable-static --disable-shared)

  cd "$work" && tar -xzf "$LAME_TGZ" && cd "lame-$LAME"
  ./configure "${common[@]}" --disable-frontend --disable-decoder >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null

  cd "$work" && tar -xzf "$OPUS_TGZ" && cd "opus-$OPUS"
  ./configure "${common[@]}" --disable-doc --disable-extra-programs >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null

  cd "$work" && tar -xzf "$OGG_TGZ" && cd "libogg-$OGG"
  ./configure "${common[@]}" >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null

  cd "$work" && tar -xzf "$VORBIS_TGZ" && cd "libvorbis-$VORBIS"
  sed -i '' 's/-force_cpusubtype_ALL//g' configure  # flag modern clang rejects
  ./configure "${common[@]}" --with-ogg="$prefix" --disable-docs --disable-examples >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null

  cd "$work" && tar -xzf "$WEBP_TGZ" && cd "libwebp-$WEBP"
  ./configure "${common[@]}" --disable-gl --disable-sdl --disable-png --disable-jpeg --disable-tiff --disable-gif --disable-wic >/dev/null
  make -j"$JOBS" >/dev/null && make install >/dev/null

  cd "$work" && tar -xzf "$VPX_TGZ" && cd "libvpx-$VPX"
  ( unset CC CXX CFLAGS CXXFLAGS
    export LDFLAGS="-arch $arch -mmacosx-version-min=$MIN_MACOS"
    ./configure --prefix="$prefix" --target="$vpx_target" \
      --extra-cflags="-arch $arch -mmacosx-version-min=$MIN_MACOS" --extra-cxxflags="-arch $arch -mmacosx-version-min=$MIN_MACOS" \
      --disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-pic --enable-vp9-highbitdepth >/dev/null
    make -j"$JOBS" >/dev/null && make install >/dev/null )

  cd "$work" && tar -xJf "$FFMPEG_TXZ" && cd "ffmpeg-$FFMPEG"
  ( unset CC CXX CFLAGS CXXFLAGS LDFLAGS
    ./configure --prefix="$prefix" --arch="$arch" --target-os=darwin --enable-cross-compile \
      --cc="clang -arch $arch" --cxx="clang++ -arch $arch" \
      --extra-cflags="-mmacosx-version-min=$MIN_MACOS -I$prefix/include" \
      --extra-ldflags="-mmacosx-version-min=$MIN_MACOS -L$prefix/lib" \
      --pkg-config-flags=--static \
      --disable-autodetect --disable-debug --disable-doc --disable-ffplay --disable-ffprobe \
      --disable-network --disable-indevs --disable-outdevs --disable-protocols --enable-protocol=file,pipe \
      --enable-videotoolbox --enable-audiotoolbox --enable-zlib --enable-bzlib --enable-iconv \
      --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libvpx --enable-libwebp \
      --enable-static --disable-shared >/dev/null
    make -j"$JOBS" >/dev/null )
  cp ffmpeg "$ROOT/$arch/ffmpeg"
}

build_arch arm64
build_arch x86_64
lipo -create "$ROOT/arm64/ffmpeg" "$ROOT/x86_64/ffmpeg" -output "$OUT/ffmpeg"
strip -x "$OUT/ffmpeg" || true
"$OUT/ffmpeg" -hide_banner -version | head -1
# Nothing but system libraries may be linked, or the app breaks on other Macs.
if otool -L "$OUT/ffmpeg" | tail -n +2 | grep -v -e '/usr/lib/' -e '/System/Library/'; then
  echo "FFmpeg links a non-system library" >&2
  exit 1
fi
