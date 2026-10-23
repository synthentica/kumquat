<p align="center">
  <img src="https://github.com/synthentica/converter/raw/previews/icon-1024.png" width="128" height="128" alt="Kumquat icon">
</p>

<h1 align="center">Kumquat</h1>

<p align="center">
  <b>Drag a file. Hold a key. Drop it on a format.</b><br>
  The zero-click file converter for macOS.
</p>

<p align="center">
  <a href="https://github.com/synthentica/converter/releases/latest"><img src="https://img.shields.io/badge/Download-Kumquat.zip-F29A2E?style=flat-square" alt="Download"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-1f2a24?style=flat-square" alt="macOS 13 or later">
  <img src="https://img.shields.io/badge/Apple%20silicon%20%26%20Intel-native-1f2a24?style=flat-square" alt="Apple silicon and Intel">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-1f2a24?style=flat-square" alt="MIT license"></a>
</p>

<p align="center">
  Free · Open source · Offline · Native Swift · No account, no uploads
</p>

<p align="center">
  <img src="https://github.com/synthentica/converter/raw/previews/hero.gif" width="860" alt="A photo is dragged out of a Finder window, Shift opens the conversion wheel under the pointer, the photo is dropped on JPG and Holiday.jpg appears next to the original">
</p>

<p align="center">
  <a href="https://github.com/synthentica/converter/raw/previews/demo.mp4">▶ Watch the 30-second demo</a>
</p>

## How it works

Start dragging any file or folder, from Finder or anywhere else, and hold a key. A wheel opens under your pointer. Drop the file on a segment, and the result appears right next to the original.

<table>
  <tr>
    <td align="center" width="33%"><img src="https://github.com/synthentica/converter/raw/previews/wheel-convert.png" alt="Convert wheel"><br><b>⇧ Shift — Convert</b><br>PNG, JPG, HEIC, MP4, M4A, PDF, DOCX, Markdown, XLSX…</td>
    <td align="center" width="33%"><img src="https://github.com/synthentica/converter/raw/previews/wheel-tools.png" alt="Tools wheel"><br><b>⌘ Command — Tools</b><br>Compress, resize, rotate, cut out the subject, merge, split…</td>
    <td align="center" width="33%"><img src="https://github.com/synthentica/converter/raw/previews/wheel-actions.png" alt="Actions wheel"><br><b>⌃ Control — Actions</b><br>AirDrop, float on top, copy, copy path, open in Terminal, move</td>
  </tr>
</table>

You can let go of the key once the wheel is open, and switch wheels by pressing another one.
Prefer the keyboard? Select files in Finder, press **⌃⌥C**, then use the arrow keys, **Tab** and **Return**.
Every key can be changed in Settings.

## PDFs that keep their looks

Most converters turn a PDF into a wall of text. Kumquat reads each page's text with its fonts and positions, finds the pictures, rules and shaded boxes in the page itself, and rebuilds the layout: columns and label/value rows become tables, wrapped lines become paragraphs, headings stay headings, pictures come along. The result is a real Word, HTML or EPUB document you can edit, not a picture of a page.

<p align="center">
  <img src="https://github.com/synthentica/converter/raw/previews/pdf-to-word.png" width="860" alt="A brochure PDF next to the Word document Kumquat made from it, with the same photo, tables, headings and shaded box">
</p>

Scanned pages are read with the Mac's own text recognition, sideways ones included.

## What it converts

Everything runs on your Mac, offline. Kumquat uses what's built into macOS (ImageIO, AVFoundation with the hardware video encoders, PDFKit, Vision, the Cocoa text system and the system archive tools), its own readers and writers for PDF layout, Office, OpenDocument and EPUB files, and a copy of [FFmpeg](https://ffmpeg.org) built into the app for the audio and video formats macOS can't write.

| Kind | From | To |
| --- | --- | --- |
| Images | JPG, PNG, HEIC, TIFF, GIF, BMP, WebP, AVIF, SVG, PSD | PNG, JPG, HEIC, TIFF, GIF, BMP, WebP, AVIF\*, PDF |
| Video | MP4, MOV, M4V, MKV, WebM, AVI, WMV, FLV | MP4, MOV, HEVC, GIF, M4A, WebM, MKV, AVI, WMV, MP3 |
| Audio | MP3, M4A, AAC, WAV, AIFF, FLAC, CAF, OGG, Opus, WMA | M4A, MP3, WAV, AIFF, FLAC, ALAC, OGG, Opus, WMA |
| PDF | PDF | DOCX, HTML, EPUB, RTF, Markdown, TXT (layout, pictures and tables kept), PNG, JPG (every page at 300 DPI), PPTX, XLSX, Pages‡ |
| Documents | DOCX, DOC, RTF, RTFD, ODT, HTML, TXT, Markdown, EPUB, text clippings, Pages‡ | PDF, DOCX, Markdown, TXT, RTF, ODT, HTML, EPUB, Pages‡ |
| Slides | PPTX, PPT‡, Keynote‡, ODP‡ | PDF, PNG, JPG (every slide), PPTX‡, Keynote‡, ODP‡ |
| Spreadsheets | XLSX, XLS, CSV, TSV, ODS, Numbers‡ | XLSX, ODS, CSV, TSV, JSON, PDF, Markdown, HTML, Numbers‡ |
| Subtitles | SRT, VTT | SRT, VTT, TXT |
| Archives | ZIP, TAR, TAR.GZ, GZ, RAR, 7Z | Extract; files and folders to ZIP, TAR.GZ, TAR, GZIP |

\* When your version of macOS can encode it.
‡ Apple's own formats and old PowerPoint files go through Keynote, Pages or Numbers (free, and on most Macs already), or [LibreOffice](https://www.libreoffice.org) when it's installed.

### Tools

| Kind | Tools |
| --- | --- |
| Images | Compress, half size, fit to 1920 px, rotate, flip, black and white, remove EXIF and GPS, square crop, trim edges, round corners, cut out the subject (macOS 14+), combine into one PDF |
| Video | Compress (HEVC), 720p, mute, snapshot, rotate, split into 1-minute parts, 2× speed, merge clips |
| Audio | Compress, mono, normalize, trim silence, split into 1-minute parts, merge |
| PDF | Compress, split pages, rotate, merge |
| Anything | ZIP, GZIP |

## Install

Kumquat needs macOS 13 Ventura or later and runs natively on Apple silicon and Intel.

Download `Kumquat.zip` from the [latest release](https://github.com/synthentica/converter/releases/latest), unzip it and move **Kumquat.app** to Applications.
Releases are signed with a Developer ID and notarized by Apple, so the app opens without a warning.

Kumquat lives in the menu bar. It doesn't need Accessibility access. The first time you use **⌃⌥C**, macOS asks whether Kumquat may read your Finder selection.

## Privacy

Kumquat never uploads anything and has no analytics. Files are read and written only on your Mac.

## Build from source

```sh
git clone https://github.com/synthentica/converter.git kumquat
cd kumquat
swift run Kumquat         # run from the terminal
swift test                # run the test suite
./scripts/bundle.sh       # build a universal build/Kumquat.app
```

You can also open `Package.swift` in Xcode. `scripts/release.sh` signs, notarizes and staples a release with your own Developer ID.

### Layout

```
Sources/KumquatCore   Format detection, the operation catalog and every converter
Sources/Kumquat       The menu bar app: drag monitor, wheel, toasts, settings
Tests                 End-to-end tests that create real files and convert them
scripts               App bundling, FFmpeg, releases, the corpus run and the icon, drawn in code
```

Adding a format usually means a few lines in `OperationCatalog.swift` and, if needed, a small engine in `Sources/KumquatCore/Engines`.

### How it's tested

Besides the unit tests, `scripts/corpus.sh` downloads a corpus of real-world files that are hard to get right: HDR and Dolby Vision iPhone video, 200-megapixel HEICs with gain maps, CMYK JPEGs, a 501-page book, scanned and rotated PDFs, XFA forms, password-protected files, Keynote, Pages and Numbers documents, damaged archives and names with Finnish and Swedish letters. It converts every one to every offered format and checks each result with outside tools: FFmpeg (SSIM and length), qpdf, veraPDF and LibreOffice. `Kumquat --benchmark` measures how fast the wheel opens and how fast common conversions run against fixed budgets.

## Third-party software

Kumquat.app includes FFmpeg, built by `scripts/build-ffmpeg.sh` under the LGPL 2.1 with LAME (LGPL), Opus, Vorbis, libvpx and libwebp (BSD). The script fetches the exact sources it builds from.

## License

[MIT](LICENSE)
