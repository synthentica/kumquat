# Third-party licenses

Kumquat.app includes an FFmpeg binary (`Contents/MacOS/ffmpeg`) built by `scripts/build-ffmpeg.sh`
from these exact sources, linked statically:

| Library | Version | License | Source |
| --- | --- | --- | --- |
| FFmpeg | 7.1 | LGPL 2.1 or later | https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz |
| LAME | 3.100 | LGPL 2 | https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz |
| Opus | 1.5.2 | BSD 3-clause | https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz |
| libogg | 1.3.5 | BSD 3-clause | https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz |
| libvorbis | 1.3.7 | BSD 3-clause | https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz |
| libvpx | 1.14.1 | BSD 3-clause + patent grant | https://github.com/webmproject/libvpx/archive/refs/tags/v1.14.1.tar.gz |
| libwebp | 1.4.0 | BSD 3-clause + patent grant | https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.4.0.tar.gz |

FFmpeg is configured without `--enable-gpl` and `--enable-nonfree`, so the binary is LGPL.
It is a separate executable that Kumquat runs, so you can replace it with your own build:
point Kumquat at it with the `ffmpegPath` default (`defaults write com.synthentica.kumquat ffmpegPath /path/to/ffmpeg`).
The build script and the sources above are everything needed to rebuild it.
