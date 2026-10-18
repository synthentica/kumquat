<p align="center">
  <img src="https://github.com/synthentica/converter/raw/previews/icon-1024.png" width="128" height="128" alt="Kumquat icon">
</p>

<h1 align="center">Kumquat</h1>

<p align="center">
  <b>The zero-click file converter for macOS.</b><br>
  Drag a file, hold a key, drop it on a format. Done.
</p>

<p align="center">
  Free · Open source · Offline · Native Swift · No account, no uploads
</p>

<p align="center">
  <img src="https://github.com/synthentica/converter/raw/previews/wheel-convert.png" width="32%" alt="Convert wheel">
  <img src="https://github.com/synthentica/converter/raw/previews/wheel-tools.png" width="32%" alt="Tools wheel">
  <img src="https://github.com/synthentica/converter/raw/previews/wheel-actions.png" width="32%" alt="Actions wheel">
</p>

## How it works

1. Start dragging any file or folder, from Finder or anywhere else.
2. Hold a key and a wheel opens under your pointer:
   - **⇧ Shift** for **Convert**: PNG, JPG, HEIC, MP4, M4A, PDF, DOCX, Markdown, XLSX…
   - **⌘ Command** for **Tools**: compress, resize, rotate, cut out the background, merge, split…
   - **⌃ Control** for **Actions**: AirDrop, float on top, copy, copy path, open in Terminal, move.
3. Drop the file on a segment. The result appears next to the original.

You can let go of the key once the wheel is open, and switch wheels by pressing another key.
Prefer the keyboard? Select files in Finder and press **⌃⌥C**, then use the arrow keys, **Tab** and **Return**.
All keys can be changed in Settings.

## What it converts

Everything runs on your Mac with the frameworks built into macOS (ImageIO, AVFoundation, PDFKit, the Cocoa text system and the system archive tools), so it's fast and works offline.

| Kind | From | To |
| --- | --- | --- |
| Images | JPG, PNG, HEIC, TIFF, GIF, BMP, WebP, AVIF, SVG, PSD | PNG, JPG, HEIC, TIFF, GIF, BMP, AVIF\*, WebP†, PDF |
| Video | MP4, MOV, M4V (+ MKV, WebM, AVI, WMV, FLV†) | MP4, MOV, HEVC, GIF, M4A (+ WebM, MKV, AVI, MP3†) |
| Audio | MP3, M4A, AAC, WAV, AIFF, FLAC, CAF (+ OGG, Opus, WMA†) | M4A, WAV, AIFF, FLAC, ALAC (+ MP3, OGG, Opus†) |
| PDF | PDF | PNG, JPG (every page at 300 DPI), DOCX, TXT, Markdown, RTF, HTML, EPUB |
| Documents | DOCX, DOC, RTF, RTFD, ODT, HTML, TXT, Markdown, EPUB | PDF, DOCX, Markdown, TXT, RTF, ODT, HTML, EPUB |
| Spreadsheets | XLSX, CSV, TSV | XLSX, CSV, TSV, JSON, PDF, Markdown, HTML |
| Subtitles | SRT, VTT | SRT, VTT, TXT |
| Archives | ZIP, TAR, TAR.GZ, GZ, RAR, 7Z | Extract; folders and files to ZIP, TAR.GZ, TAR |

\* When your version of macOS can encode it. † With [FFmpeg](https://ffmpeg.org) installed (`brew install ffmpeg`); Kumquat finds it automatically.

### Tools

| Kind | Tools |
| --- | --- |
| Images | Compress, half size, fit to 1920 px, rotate, flip, black and white, remove EXIF and GPS, cut out the subject (macOS 14+), combine into one PDF |
| Video | Compress (HEVC), 720p, mute, snapshot, merge clips |
| Audio | Compress, mono, merge |
| PDF | Compress, split pages, rotate, merge |
| Anything | ZIP |

## Install

Kumquat needs macOS 13 Ventura or later and runs natively on Apple silicon and Intel.

Download `Kumquat.zip` from the latest build, unzip it and move **Kumquat.app** to Applications.
Until releases are notarized, open it the first time with right-click → **Open**.

Kumquat lives in the menu bar. It doesn't need Accessibility access. The first time you use **⌃⌥C**, macOS asks whether Kumquat may read your Finder selection.

## Build from source

```sh
git clone https://github.com/synthentica/converter.git kumquat
cd kumquat
swift run Kumquat         # run from the terminal
swift test                # run the test suite
./scripts/bundle.sh       # build a universal build/Kumquat.app
```

You can also open `Package.swift` in Xcode.

### Layout

```
Sources/KumquatCore   Format detection, the operation catalog and every converter
Sources/Kumquat       The menu bar app: drag monitor, wheel, toasts, settings
Tests                 End-to-end tests that create real files and convert them
scripts               App bundling and the icon, drawn in code
```

Adding a format usually means a few lines in `OperationCatalog.swift` and, if needed, a small engine in `Sources/KumquatCore/Engines`.

## Privacy

Kumquat never uploads anything and has no analytics. Files are read and written only on your Mac.

## License

[MIT](LICENSE)
