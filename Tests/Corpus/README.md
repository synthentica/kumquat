# Kumquat real-world test corpus

`manifest.json` lists 77 publicly downloadable, hard-to-convert files (about 151 MB in total, largest 33 MB) that CI downloads at test time, caches, converts with Kumquat's engines, and checks with ffprobe, SSIM/PSNR (FFmpeg), veraPDF and LibreOffice. **None of these files are committed to this repository.** They are fetched from their upstream hosts and checked against the pinned `sha256` before use.

Files that cannot be sourced this way are generated in CI. See [Generated in CI](#generated-in-ci).

## Manifest format

Each entry in the array is:

| field | meaning |
|---|---|
| `id` | Stable kebab-case identifier. Use it as the cache file name and the test name. |
| `category` | One of `heic`, `iphone-video`, `vfr`, `video`, `audio`, `pdf`, `office`, `archive`, `image`. |
| `url` | Direct download URL. Git-hosted files are pinned to a commit SHA (never a branch), so the bytes cannot change. |
| `sha256`, `bytes` | Measured on 2026-10-18 from a fresh download. CI must reject a file whose hash does not match. |
| `license` | License or terms of the file (see [Licenses](#licenses)). |
| `source_page` | Human-readable page that documents the file and its license. |
| `why_hard` | What the file exercises, verified by inspecting it (ffprobe, HEIF box parsing, unzip, pdfinfo). |
| `expected` | `convert`: every listed target must succeed and pass validation. `clean-error`: Kumquat must fail with a typed, user-facing error. It must not crash, hang, or write partial or blank output. |
| `targets` | Kumquat operation ids without their wheel prefix, as `Kumquat --corpus` (`Sources/Kumquat/CorpusRunner.swift`) resolves them: `convert.<target>` or `tools.<target>`. Format targets use `FileFormat` raw values (`jpeg`, `png`, `heic`, `avif`, `tiff`, `webp`, `gif`, `pdf`, `mp4`, `mov`, `webm`, `m4a`, `mp3`, `wav`, `flac`, `docx`, `txt`, `odt`, `html`, `pptx`, `key`, `odp`, `xlsx`, `csv`, `ods`, …). Special ids: `hevc` (HEVC MP4), `alac`, `extract` (archives), `snapshot` (video frame tool). Same-format targets are omitted because Kumquat never offers them. PDF and slide `png`/`jpeg` mean one image per page or slide. |

### Suggested CI download step

```sh
jq -r '.[] | [.id, .url, .sha256] | @tsv' Tests/Corpus/manifest.json |
while IFS=$'\t' read -r id url sha; do
  f="$CORPUS_CACHE/$id"
  [ -f "$f" ] && echo "$sha  $f" | shasum -a 256 -c --quiet && continue
  curl -fsSL --retry 5 --retry-all-errors -o "$f.part" "$url"
  echo "$sha  $f.part" | shasum -a 256 -c --quiet && mv "$f.part" "$f"
done
```

Key `actions/cache` on `hashFiles('Tests/Corpus/manifest.json')`. Keep the original extension when a converter sniffs by name (for example `${id}.${url##*.}`). Most files come from `raw.githubusercontent.com`. Two come from GitHub release assets (`pdf-progit-501-pages`, `targz-zlib-source`; follow redirects) and three from `gitlab.com` (Inkscape and libtiff).

## Contents

| category | count | ids |
|---|---|---|
| iPhone / Apple HEIC | 4 | gain-map HEIC (iPhone 13 Pro), Live Photo still (iPhone 11 Pro), iOS 11 HEIC (iPhone 8), Vision Pro spatial stereo pair |
| iPhone / HDR / Dolby Vision video | 6 | iPhone 12 Pro HEVC HLG + DV 8.4 MOV, iPhone 14 Pro Live Photo MOV, iPhone X rotated VFR MOV, DV profile 8.1, DV profile 5, HDR10 PQ HEVC |
| variable frame rate | 1 (+2) | OBS screen recording. The iPhone X MOV and the iPhone 12 Pro MOV are also VFR. |
| other video | 12 | MKV 2 audio + 8 subs, WebM VP9, WebM AV1, WebM 3 video + 2 audio, AVI MJPEG (Canon), AVI MPEG-4 + AC-3, ASF/WMV-family, WMV2-in-MKV, H.264 High 10, rotated Android, HEVC with no audio, MP4 with 2 video + 2 audio |
| audio | 8 | MP3 + ID3 PNG art, FLAC 24/96, FLAC 5.1, FLAC 7.1, Ogg Vorbis, Opus, WMA v2, ALAC in CAF |
| PDF | 8 | 501-page book, password, scanned image-only (1 page and 4 rotated pages), AcroForm (IRS 1040), XFA form, PDF/A-1b, veraPDF PDF/A-2b pass |
| Office / iWork / ODF | 15 | Google Slides PPTX, PowerPoint PPTX with charts/tables/groups, BIFF8 XLS, XLSX with formulas/merges/charts, XLSX with 50k merges, DOCX with images in tables, DOCX with chartex charts, truncated DOCX, ODT, ODS, ODP, Keynote, Keynote zipped bundle, Pages, Numbers |
| archives | 7 | ZIP of office docs, TAR.GZ (zlib), 7z with umlauts, encrypted 7z, corrupted 7z, RAR3 with Unicode names, encrypted RAR5 |
| images | 16 | CMYK JPEG (2), 16-bit PNG, animated GIF, animated WebP, 10-bit HDR AVIF, AVIF sequence, multi-page TIFF, TIFF IFD loop, Inkscape SVG with filters, multi-script SVG text, layered PSD, CMYK PSD with spot channel, 200 MP HEIC, EXIF orientation 6, GIF decompression bomb |

| id | category | size | license | expected |
|---|---|---|---|---|
| `heic-iphone13pro-hdr-gainmap` | heic | 233 KB | MIT | convert |
| `heic-iphone11pro-livephoto-still` | heic | 5.9 MB | free use (metadata-extractor-images) | convert |
| `heic-iphone8-ios11` | heic | 1.4 MB | free use (metadata-extractor-images) | convert |
| `heic-visionpro-spatial-stereo` | heic | 1.2 MB | BSD-3-Clause | convert |
| `mov-iphone12pro-hevc-hlg-dolbyvision-8.4` | iphone-video | 33.3 MB | Public domain | convert |
| `mov-iphone14pro-livephoto-video` | iphone-video | 5.0 MB | free use (metadata-extractor-images) | convert |
| `mov-iphoneX-h264-rotated-vfr` | iphone-video | 5.1 MB | free use (metadata-extractor-images) | convert |
| `mp4-dolbyvision-profile8.1` | iphone-video | 3.4 MB | BSD-3-Clause | convert |
| `mp4-dolbyvision-profile5` | iphone-video | 4.3 MB | BSD-3-Clause | convert |
| `mp4-hevc-hdr10-pq` | iphone-video | 312 KB | BSD-3-Clause | convert |
| `mp4-obs-screen-recording-vfr` | vfr | 4.6 MB | BSD-3-Clause | convert |
| `mkv-multi-audio-8-subtitles` | video | 30.3 MB | CC-BY | convert |
| `webm-vp9-720p` | video | 17 KB | BSD-3-Clause | convert |
| `webm-av1` | video | 18 KB | BSD-3-Clause | convert |
| `webm-multitrack-3video-2audio` | video | 186 KB | BSD-3-Clause | convert |
| `avi-canon-mjpeg-pcm` | video | 3.0 MB | free use (metadata-extractor-images) | convert |
| `avi-mpeg4-asp-ac3` | video | 101 KB | BSD-3-Clause | convert |
| `asf-wmv-msmpeg4-wma` | video | 140 KB | MIT | convert |
| `mkv-wmv2-vorbis` | video | 87 KB | BSD-3-Clause | convert |
| `mp4-h264-high10` | video | 154 KB | BSD-3-Clause | convert |
| `mp4-android-rotated-90` | video | 5.3 MB | free use (metadata-extractor-images) | convert |
| `mp4-hevc-no-audio` | video | 303 KB | BSD-3-Clause | convert |
| `mp4-2video-2audio` | video | 1023 KB | BSD-3-Clause | convert |
| `mp3-id3-png-cover` | audio | 177 KB | BSD-3-Clause | convert |
| `flac-24bit-96khz` | audio | 3.3 MB | CC0-1.0 | convert |
| `flac-6ch-5.1` | audio | 168 KB | CC0-1.0 | convert |
| `flac-8ch-7.1` | audio | 228 KB | CC0-1.0 | convert |
| `ogg-vorbis-mono` | audio | 4 KB | BSD-3-Clause | convert |
| `opus-stereo` | audio | 14 KB | BSD-3-Clause | convert |
| `wma-v2` | audio | 34 KB | MIT | convert |
| `caf-alac` | audio | 6 KB | MIT | convert |
| `pdf-progit-501-pages` | pdf | 18.0 MB | CC-BY-NC-SA-3.0 | convert |
| `pdf-password-libreoffice` | pdf | 12 KB | CC-BY-SA-4.0 | clean-error |
| `pdf-scanned-gutenberg-page` | pdf | 164 KB | Public domain | convert |
| `pdf-scanned-rotated-4pages` | pdf | 75 KB | CC-BY-SA-4.0 | convert |
| `pdf-acroform-irs-1040` | pdf | 299 KB | Public domain | convert |
| `pdf-xfa-dynamic-form` | pdf | 2.9 MB | Gov. of Canada form via pdf.js corpus | clean-error |
| `pdf-a1b-ghostscript` | pdf | 16 KB | CC-BY-SA-4.0 | convert |
| `pdf-a2b-verapdf-pass` | pdf | 7 KB | CC-BY-4.0 | convert |
| `pptx-google-slides-export` | office | 41 KB | Apache-2.0 | convert |
| `pptx-powerpoint-charts-tables-groups` | office | 583 KB | Apache-2.0 | convert |
| `xls-biff8-real-world` | office | 803 KB | Apache-2.0 | convert |
| `xlsx-formulas-merges-charts` | office | 756 KB | Apache-2.0 | convert |
| `xlsx-50000-merged-cells` | office | 829 KB | Apache-2.0 | convert |
| `docx-images-in-tables` | office | 25 KB | MIT | convert |
| `docx-chartex` | office | 130 KB | Apache-2.0 | convert |
| `docx-truncated-zip` | office | 19 KB | Apache-2.0 | clean-error |
| `odt-text-document` | office | 31 KB | MIT | convert |
| `ods-table-with-title` | office | 12 KB | MIT | convert |
| `odp-presentation` | office | 34 KB | MIT | convert |
| `keynote-2013-iwa` | office | 268 KB | MIT | convert |
| `keynote-2018-zipped-bundle` | office | 53 KB | MIT | clean-error |
| `pages-2013-iwa` | office | 232 KB | MIT | convert |
| `numbers-2013-iwa` | office | 175 KB | MIT | convert |
| `zip-nested-office-docs` | archive | 727 KB | MIT | convert |
| `targz-zlib-source` | archive | 1.4 MB | Zlib | convert |
| `7z-umlaut-solid` | archive | 163 B | LGPL-2.1-or-later | convert |
| `7z-encrypted` | archive | 251 B | LGPL-2.1-or-later | clean-error |
| `7z-data-corrupted` | archive | 657 B | LGPL-2.1-or-later | clean-error |
| `rar3-unicode-names` | archive | 163 B | ISC | convert |
| `rar5-encrypted` | archive | 2 KB | ISC | clean-error |
| `jpeg-cmyk-adobe` | image | 145 KB | CC-BY-SA | convert |
| `jpeg-cmyk-small` | image | 29 KB | MIT-CMU | convert |
| `png-16bit-hdr-room` | image | 1.5 MB | CC-BY-4.0 | convert |
| `gif-animated-42-frames` | image | 271 KB | MIT-CMU | convert |
| `webp-animated-42-frames` | image | 203 KB | MIT-CMU | convert |
| `avif-10bit-hdr-p3` | image | 970 KB | Public domain | convert |
| `avif-sequence-animated` | image | 29 KB | MIT-CMU | convert |
| `tiff-multipage` | image | 816 B | MIT-CMU | convert |
| `tiff-ifd-loop` | image | 312 B | libtiff license | clean-error |
| `svg-inkscape-filters` | image | 582 KB | GPL-2.0-or-later | convert |
| `svg-inkscape-i18n-text` | image | 26 KB | GPL-2.0-or-later | convert |
| `psd-layer-effects` | image | 718 KB | MIT | convert |
| `psd-cmyk-spot-channels` | image | 393 KB | MIT | convert |
| `heic-samsung-200mp-gainmap` | image | 2.3 MB | BSD-3-Clause | convert |
| `jpeg-exif-orientation-6` | image | 344 KB | MIT | convert |
| `gif-decompression-bomb` | image | 44 B | MIT-CMU | clean-error |

Passwords, for tests that also check the "correct password" path: `pdf-password-libreoffice` user `openpassword` / owner `permissionpassword`; `7z-encrypted` `secret`; `rar5-encrypted` `password`. All three come from the upstream test suites.

## Sources

| source | what we take | license / terms |
|---|---|---|
| [chromium/chromium `media/test/data`](https://github.com/chromium/chromium/tree/main/media/test/data) | DV 5 and 8.1, HDR10, VP9, AV1, AVI, WMV2, High 10, no-audio, multitrack, OBS VFR, MP3 + ID3, Ogg, Opus | BSD-3-Clause. The DV clips are cut from Dolby's developer samples (their `README.md` documents this). |
| [drewnoakes/metadata-extractor-images](https://github.com/drewnoakes/metadata-extractor-images) | iPhone HEIC (8, 11 Pro), iPhone MOV (X, 14 Pro Live Photo), Canon AVI, Nokia MP4 | README: "You are free to use these media files however you wish." |
| [immich-app/test-assets](https://github.com/immich-app/test-assets) | iPhone 12 Pro HLG/DV 8.4 MOV, 10-bit HDR AVIF | README: "All assets are public domain". |
| [johncf/apple-hdr-heic](https://github.com/johncf/apple-hdr-heic), mirrored in [imazen/heic `testdata/apple-hdr`](https://github.com/imazen/heic/tree/main/testdata/apple-hdr) | iPhone 13 Pro gain-map HEIC | MIT. The upstream copy is a Git LFS object. The pinned URL points to the plain-blob mirror, and its sha256 equals the upstream LFS oid. |
| [bigcat88/pillow_heif `tests/images`](https://github.com/bigcat88/pillow_heif) | Vision Pro spatial photo, 200 MP Samsung HEIC | BSD-3-Clause (repository) |
| [ietf-wg-cellar/matroska-test-files](https://github.com/ietf-wg-cellar/matroska-test-files) | test5.mkv | CC-BY (Blender Foundation content) |
| [ietf-wg-cellar/flac-test-files](https://github.com/ietf-wg-cellar/flac-test-files) | FLAC 24/96, 5.1, 7.1 | CC0-1.0 |
| [Borewit/music-metadata `test/samples`](https://github.com/Borewit/music-metadata) | WMA, ASF, ALAC CAF | MIT |
| [py-pdf/sample-files](https://github.com/py-pdf/sample-files) | password PDF, PDF/A-1b | CC-BY-SA-4.0 |
| [OCRmyPDF `tests/resources`](https://github.com/ocrmypdf/OCRmyPDF/tree/main/tests/resources) | scanned PDFs, CMYK JPEG | CC-BY-SA-4.0 and per-file sources in its `README.rst` (c03-29 is a public-domain Project Gutenberg scan) |
| [mozilla/pdf.js `test/pdfs`](https://github.com/mozilla/pdf.js/tree/master/test/pdfs) | IRS 1040 AcroForm, XFA form | Apache-2.0 repository. The IRS form is US-government public domain. The XFA file is a Government of Canada form (test use only). |
| [veraPDF/veraPDF-corpus](https://github.com/veraPDF/veraPDF-corpus) | PDF/A-2b pass file | CC-BY-4.0 |
| [progit/progit2 releases](https://github.com/progit/progit2/releases/tag/2.1.450) | 501-page PDF | CC-BY-NC-SA-3.0 |
| [apache/poi `test-data`](https://github.com/apache/poi/tree/trunk/test-data) | PowerPoint PPTX, BIFF8 XLS, XLSX, chartex DOCX, truncated DOCX | Apache-2.0 |
| [Unstructured-IO/unstructured `example-docs`](https://github.com/Unstructured-IO/unstructured/tree/main/example-docs) | Google Slides PPTX | Apache-2.0 |
| [docling-project/docling `tests/data`](https://github.com/docling-project/docling/tree/main/tests/data) | DOCX, ODT, ODS, ODP, Keynote, Pages, Numbers | MIT |
| [microsoft/markitdown test files](https://github.com/microsoft/markitdown) | ZIP | MIT |
| [madler/zlib v1.3.1 release](https://github.com/madler/zlib/releases/tag/v1.3.1) | TAR.GZ (sha256 matches the upstream-published hash) | Zlib |
| [miurahr/py7zr `tests/data`](https://github.com/miurahr/py7zr) | 7z files | LGPL-2.1-or-later |
| [markokr/rarfile `test/files`](https://github.com/markokr/rarfile) | RAR files | ISC |
| [python-pillow/Pillow `Tests/images`](https://github.com/python-pillow/Pillow/tree/main/Tests/images) | CMYK JPEG, animated GIF/WebP, AVIF sequence, multi-page TIFF, decompression bomb | MIT-CMU (Pillow license) |
| [libjxl/testdata](https://github.com/libjxl/testdata) | 16-bit PNG | CC-BY-4.0 |
| [Inkscape `share/examples`](https://gitlab.com/inkscape/inkscape/-/tree/master/share/examples) | SVGs | GPL-2.0-or-later (shipped with Inkscape) |
| [psd-tools `tests/psd_files`](https://github.com/psd-tools/psd-tools) | PSDs | MIT |
| [libtiff `test/images`](https://gitlab.com/libtiff/libtiff/-/tree/master/test/images) | IFD-loop TIFF | libtiff (BSD-like) license |
| [recurser/exif-orientation-examples](https://github.com/recurser/exif-orientation-examples) | EXIF orientation JPEG | MIT |

### Licenses

Everything is used only as test input. Nothing is redistributed in this repository or in the app. Points to watch:

- **Pro Git is CC-BY-NC-SA-3.0 (non-commercial).** Downloading it for internal CI is fine, but never bundle it or ship it. If that is unacceptable, swap in the generated 500-page PDF below.
- The **CC-BY-SA** files (py-pdf, OCRmyPDF) and **GPL** files (Inkscape SVGs) must not be copied into the repo or the product.
- The **XFA form** (`pdf-xfa-dynamic-form`) has no explicit license beyond being redistributed in pdf.js's test corpus. Keep it test-only, or drop it if legal prefers.
- Attribution for CC-BY files lives in the `license` field of each entry and in this file.

## Generated in CI

Some inputs cannot be sourced: they are not publicly available, would be too large, or depend on the machine state. Generate them in a setup step, cache them like the downloaded files (keyed by the generator script hash), and produce them deterministically where possible (fixed seeds, fixed timestamps).

`Kumquat --corpus` already generates `gen-pdf-500-pages`, `gen-pdf-password`, `gen-zip-truncated`, `gen-name-<category>` (non-ASCII names) and `gen-icloud-stub` (see `Generated` in `Sources/Kumquat/CorpusRunner.swift`). The rest of this table lists further cases worth adding there.

| what | why it is not sourced | how to generate on macos-15 |
|---|---|---|
| **500+ page PDF** (and a 2,000-page stress variant) | Pro Git is NC-licensed and 18 MB. A synthetic file gives exact control. | CoreGraphics: `CGContext(consumer:mediaBox:auxiliaryInfo:)`, then `beginPDFPage`/`endPDFPage` × 500 with text (CTFrameDraw), vector paths and one embedded JPEG every 10 pages. Set a fixed `kCGPDFContextCreator` and no date, so the bytes are stable. |
| **Password PDFs** (user password; owner-only permissions) | Only one sourced sample. Need both the "must prompt" and the "opens but restricted" cases. | PDFKit: `PDFDocument(url:)!.write(to:withOptions: [.userPasswordOption: "user", .ownerPasswordOption: "owner"])`. For owner-only, pass only `.ownerPasswordOption`, plus `.accessPermissionsOption` on macOS 14+. Owner-only should *convert*. A user password should be a clean error unless a password is supplied. |
| **Truncated / corrupted ZIP** | Upstream suites mostly ship `.uu`-encoded or generated cases. | Take `zip-nested-office-docs`. Variant (a): `head -c $((size/2))` (no central directory). Variant (b): drop only the last 22 bytes (EOCD). Variant (c): flip one byte inside the first member's data (CRC mismatch). Variant (d): a ZIP with >65,535 entries via `python3 -c 'import zipfile…'` (ZIP64). All but (d) are `clean-error`. |
| **Truncated media / image** | Same reason. | `head -c` 60% of `mov-iphone12pro-…` (`moov` is after `mdat`, so it becomes unplayable → clean-error), 60% of `mp4-dolbyvision-profile8.1` (fragmented, `moov` + `moof`s at the front, so it should convert the surviving fragments or error cleanly), 50% of `jpeg-exif-orientation-6`. Also a 0-byte file per category, and a PNG renamed `.jpg` (content sniffing). |
| **Unicode / awkward file names** | They are a property of the path, not the bytes. | Copy corpus files to `Ääkkönen å ö.heic` in both **NFC and NFD** (`python3 -c "import unicodedata"`; APFS preserves the form you write), plus an emoji name, a 255-byte UTF-8 name, a leading-dot name, a name containing `:` (shown as `/` in Finder), and a path deeper than 1024 bytes. Each must convert, and the output name must keep the same normalization. |
| **iPhone ProRes MOV** (422 HQ, 4444, and ProRes HLG) | No public iPhone ProRes recording found. These files are 1–6 GB/min and exceed the 200 MB cap. | AVFoundation: `AVAssetWriter` with `AVVideoCodecType.proRes422HQ` / `.proRes4444` and `AVVideoColorPropertiesKey` = ITU_R_2020 / ITU_R_2100_HLG / ITU_R_2020 (10-bit `kCVPixelFormatType_422YpCbCr10`), fed with 2 s of frames decoded from `mov-iphone12pro-…`. Alternatively `ffmpeg -c:v prores_videotoolbox -profile:v hq` or `prores_ks`. Add the `com.apple.quicktime.make/model` metadata keys to mimic an iPhone file. |
| **HLG HEVC without Dolby Vision** | iPhones always add DV 8.4 to HLG recordings. | FFmpeg 7+: `ffmpeg -i mov-iphone12pro-… -map 0:v:0 -map 0:a:0 -c copy -bsf:v dovi_rpu=strip=1 hlg.mov`, which strips the RPU NAL units (type 62) and the DOVI side data, so no `dvcC`/`dvvC` box is written. Older FFmpeg: `-bsf:v filter_units=remove_types=62`. Or re-encode with `hevc_videotoolbox` and HLG colour tags. Check with `ffprobe` that no DOVI configuration record remains. |
| **True macOS/iOS screen recording** (QuickTime / Cmd-Shift-5, highly VFR with idle gaps) | None public. `screencapture -v` needs the Screen Recording TCC permission, which a hosted runner cannot grant: TCC.db is SIP-protected and no user can click "Allow". | `AVAssetWriter` (H.264 via `hevc`/`h264_videotoolbox`) with hand-picked PTS: 60 fps bursts, then a 3 s gap with a single frame, then 1-frame-per-second segments. Add the `com.apple.quicktime.software` metadata. FFmpeg alternative: `-vf "setpts='if(gt(N,120),PTS*20,PTS)'" -fps_mode vfr`. |
| **ALAC in .m4a** (16/44.1 and 24/96) | Only ALAC-in-CAF and ALAC-in-MKA samples exist. | `afconvert -f m4af -d alac flac-24bit-96khz.flac alac-24-96.m4a` (afconvert reads FLAC on macOS 11+). For a 16/44.1 variant, first `afconvert -f WAVE -d LEI16@44100 in.flac tmp.wav`, then `afconvert -f m4af -d alac tmp.wav alac-16-44.m4a`. |
| **5.1 / 7.1 AAC and AC-3 in MP4** | The sourced multichannel files are FLAC only. | `afconvert -f m4af -d aac -l AAC_5_1 flac-6ch-5.1.flac aac51.m4a`; `ffmpeg -i flac-8ch-7.1.flac -c:a ac3 -b:a 640k ac3.mp4`. |
| **HEIC with depth / disparity map and portrait matte** | No public iPhone Portrait-mode HEIC with depth was found (searched metadata-extractor, Immich, pillow_heif, libheif, imazen/heic and GitHub code search). | ImageIO: `CGImageDestinationAddImage` + `CGImageDestinationAddAuxiliaryDataInfo(dest, kCGImageAuxiliaryDataTypeDisparity, dict)`. Build `dict` from an `AVDepthData` made from a synthetic Float16 `CVPixelBuffer`, and add `kCGImageAuxiliaryDataTypePortraitEffectsMatte` too. Write `public.heic`. |
| **Huge (>50 MP) JPEG / PNG / 16-bit TIFF** | A real 200 MP HEIC is sourced, but no permissively licensed >50 MP JPEG/PNG was reachable. | `ffmpeg -f lavfi -i "mandelbrot=s=10000x7500:end_pts=1" -frames:v 1 huge.png` (75 MP). `sips -s format jpeg huge.png --out huge.jpg`. For a 16-bit TIFF, use `-pix_fmt rgb48le`. |
| **Realistic multi-page TIFF** (scanned, LZW/G4, mixed page sizes) | The sourced one is 3 × 10×10 px. | ImageIO: a `CGImageDestination` of type `public.tiff` with N images (render the pages of `pdf-scanned-rotated-4pages` with PDFKit) and `kCGImagePropertyTIFFDictionary` compression set per page. |
| **WMV with real `.wmv` extension** | FFmpeg can encode WMV1/WMV2 only, not WMV3 (WMV9) or VC-1. | `ffmpeg -i webm-vp9-720p.webm -c:v wmv2 -c:a wmav2 -f asf out.wmv`. See the note on WMV9 under gaps. |
| **iCloud placeholder (dataless) files** | See below. | Not possible on hosted runners. Only the legacy stub can be generated. |

### Can a real dataless iCloud placeholder be made on a CI runner?

No, not on a GitHub-hosted `macos-15` runner.

Since macOS 10.15, an evicted iCloud Drive file is an APFS "dataless" file: the inode has the `SF_DATALESS` flag, and reading it triggers a materialization upcall to the File Provider daemon. Creating one requires either of two things, and a hosted runner has neither:

- **An actual File Provider domain.** This is iCloud Drive signed in to an Apple ID, or a signed, user-approved `NSFileProviderReplicatedExtension` app. Eviction (`brctl evict`, `fileproviderctl evict`, or `NSFileProviderManager.evictItem`) then works only on items inside that domain. Hosted runners have no Apple ID session, and registering a File Provider extension needs a signed app bundle plus user approval, so it cannot be done headlessly.
- **The kernel's dataless APIs directly.** The "make dataless" calls are restricted to Apple-entitled processes. `chflags` cannot set `SF_DATALESS`, even as root, with SIP enabled.

What CI *can* do:

1. **Legacy placeholder stubs** (pre-Sonoma iCloud and other sync clients): create `.Name.pdf.icloud` binary plists containing `NSURLNameKey`, `NSURLFileSizeKey` and `NSURLFileResourceTypeKey` with `plutil`. Kumquat should recognise these, show "not downloaded", and not try to convert the stub.
2. **Unit-test the detection logic** by injecting `URLResourceValues` (`ubiquitousItemDownloadingStatus = .notDownloaded`, `isUbiquitousItem = true`) through the protocol Kumquat uses to read resource values. Also simulate a read that fails with `EDEADLK`/`ETIMEDOUT`, as materialization failures surface.
3. **End-to-end on a self-hosted runner** (a Mac signed in to a test Apple ID with iCloud Drive enabled): copy a corpus file into `~/Library/Mobile Documents/com~apple~CloudDocs/`, wait for upload, `brctl evict <file>`, then verify with `ls -lO` (the `dataless` flag) before running Kumquat on it.

## Gaps: searched for but not found

All of these are covered by generation above where possible. Sandbox egress allowed only GitHub, gitlab.com, bitbucket.org and developer.apple.com, so these sources could **not** be checked: samples.ffmpeg.org / fate-suite.ffmpeg.org, kodi.wiki, Wikimedia Commons, loc.gov, archive.org, Dolby (`developer.dolby.com`, `media.developer.dolby.com`, `ott.dolby.com`), exiftool.org, file-examples.com, filesamples.com, devstreaming-cdn.apple.com (Apple HDR/HLS sample streams), git.libreoffice.org and huggingface.co. The Chromium DV clips are cut from Dolby's samples, so the DV need is still covered.

- **iPhone ProRes .mov**: none in any reachable corpus. Generate instead.
- **iPhone Portrait-mode HEIC with depth/matte**: none found (checked metadata-extractor-images, Immich, pillow_heif, libheif, imazen/heic, apple-hdr-heic and GitHub code search for `portraiteffectsmatte`). The sourced iPhone HEICs have only thumbnails, Exif and XMP. The gain-map sample has the HDR gain-map aux image only. Generate instead.
- **Real QuickTime/iOS screen recording**: none found. The OBS remux and the VFR iPhone X clip stand in. Generate instead.
- **ALAC .m4a**: only CAF/MKA ALAC found. Generate instead.
- **WMV9 / VC-1 (`WMV3`/`WVC1`) file**: none found in reachable test suites (music-metadata only has MS-MPEG4v3 and WMV2 ASF files). It cannot be generated with FFmpeg either (no encoder). The FATE suite (`samples.ffmpeg.org/V-codecs/WMV3`, `vc1/`) has them, but it was unreachable from this sandbox. Add one later after verifying it from a machine that can reach it.
- **Huge >50 MP JPEG/PNG**: none with a clear license reachable. Use the 200 MP HEIC plus the generated PNG/JPEG.
- **Keynote/Pages/Numbers created by current (14.x) iWork**: only 2013–2018-era samples are public (docling). There is no way to generate them on CI because the iWork apps are not installed on runners.
