# Kumquat corpus

**231 of 238 conversions pass (97.1 %)**, judged by ffprobe, FFmpeg SSIM, sips, qpdf, veraPDF and LibreOffice. 1 more were skipped and are listed below with the reason.

Tools: ffmpeg yes, ffprobe yes, qpdf yes, sips yes, soffice yes, verapdf yes

| Category | Pass | Total |
| --- | ---: | ---: |
| archive | 7 | 8 |
| audio | 35 | 35 |
| heic | 11 | 12 |
| image | 51 | 53 |
| iphone-video | 18 | 18 |
| office | 41 | 41 |
| other | 1 | 1 |
| pdf | 34 | 34 |
| vfr | 3 | 3 |
| video | 30 | 33 |

## Not passing

| File | Target | Verdict | Why | ms |
| --- | --- | --- | --- | ---: |
| heic-iphone13pro-hdr-gainmap | avif | fail | not-offered |  |
| webm-av1 | mp4 | fail | error: webm-av1.webm: ffmpeg: IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver | 568 |
| webm-av1 | gif | fail | error: webm-av1.webm: ffmpeg: [out#0/gif @ 0x600000c84540] Error writing trailer: Invalid argument | 131 |
| asf-wmv-msmpeg4-wma | mp4 | fail | asf-wmv-msmpeg4-wma.mp4: SSIM 0.847 < 0.90 | 625 |
| pptx-google-slides-export | key | skipped | no app on this Mac writes Keynote |  |
| rar3-unicode-names | extract | fail | error: rar3-unicode-names.rar: tar: tar: Error exit delayed from previous errors. | 36 |
| png-16bit-hdr-room | avif | fail | not-offered |  |
| psd-cmyk-spot-channels | png | fail | psd-cmyk-spot-channels.png: SSIM 0.424 < 0.95 | 38 |

## Every conversion

| File | Target | Verdict | ms | Notes |
| --- | --- | --- | ---: | --- |
| heic-iphone13pro-hdr-gainmap | jpeg | pass | 218 | SSIM 0.998 |
| heic-iphone13pro-hdr-gainmap | png | pass | 619 | SSIM 1.000 |
| heic-iphone13pro-hdr-gainmap | avif | fail |  |  |
| heic-iphone13pro-hdr-gainmap | tiff | pass | 210 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | jpeg | pass | 155 | SSIM 0.999 |
| heic-iphone11pro-livephoto-still | png | pass | 2112 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | tiff | pass | 1215 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | pdf | pass | 3011 | PDF/A not claimed |
| heic-iphone8-ios11 | jpeg | pass | 95 | SSIM 0.999 |
| heic-iphone8-ios11 | png | pass | 1901 | SSIM 1.000 |
| heic-visionpro-spatial-stereo | jpeg | pass | 159 | SSIM 0.999 |
| heic-visionpro-spatial-stereo | png | pass | 879 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp4 | pass | 241 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | hevc | pass | 7047 | SSIM 0.995 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | gif | pass | 39300 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp3 | pass | 349 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | m4a | pass | 23 |  |
| mov-iphone14pro-livephoto-video | mp4 | pass | 48 | SSIM 1.000 |
| mov-iphone14pro-livephoto-video | gif | pass | 2858 |  |
| mov-iphone14pro-livephoto-video | snapshot | pass | 222 |  |
| mov-iphoneX-h264-rotated-vfr | mp4 | pass | 91 | SSIM 1.000 |
| mov-iphoneX-h264-rotated-vfr | gif | pass | 4538 |  |
| mov-iphoneX-h264-rotated-vfr | m4a | pass | 168 |  |
| mp4-dolbyvision-profile8.1 | mov | pass | 25 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | hevc | pass | 33 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | gif | pass | 1808 |  |
| mp4-dolbyvision-profile5 | mov | pass | 74 | SSIM 1.000 |
| mp4-dolbyvision-profile5 | hevc | pass | 949 | SSIM 0.992 |
| mp4-hevc-hdr10-pq | mov | pass | 47 | SSIM 1.000 |
| mp4-hevc-hdr10-pq | webm | pass | 5082 | SSIM 0.951 |
| mp4-obs-screen-recording-vfr | mov | pass | 223 | SSIM 1.000 |
| mp4-obs-screen-recording-vfr | gif | pass | 2997 |  |
| mp4-obs-screen-recording-vfr | m4a | pass | 24 |  |
| mkv-multi-audio-8-subtitles | mp4 | pass | 1336 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | mov | pass | 1294 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | m4a | pass | 1125 |  |
| webm-vp9-720p | mp4 | pass | 2662 | SSIM 0.951 |
| webm-vp9-720p | gif | pass | 2330 |  |
| webm-av1 | mp4 | fail | 568 |  |
| webm-av1 | gif | fail | 131 |  |
| webm-multitrack-3video-2audio | mp4 | pass | 3338 | SSIM 1.000 |
| avi-canon-mjpeg-pcm | mp4 | pass | 577 | SSIM 0.980 |
| avi-canon-mjpeg-pcm | gif | pass | 2131 |  |
| avi-canon-mjpeg-pcm | m4a | pass | 110 |  |
| avi-mpeg4-asp-ac3 | mp4 | pass | 524 | SSIM 0.980 |
| avi-mpeg4-asp-ac3 | m4a | pass | 365 |  |
| asf-wmv-msmpeg4-wma | mp4 | fail | 625 | SSIM 0.847 |
| asf-wmv-msmpeg4-wma | m4a | pass | 337 |  |
| asf-wmv-msmpeg4-wma | mp3 | pass | 287 |  |
| mkv-wmv2-vorbis | mp4 | pass | 464 | SSIM 0.954 |
| mkv-wmv2-vorbis | m4a | pass | 178 |  |
| mp4-h264-high10 | mov | pass | 126 | SSIM 1.000 |
| mp4-android-rotated-90 | mov | pass | 152 | SSIM 1.000 |
| mp4-android-rotated-90 | gif | pass | 3488 |  |
| mp4-hevc-no-audio | mov | pass | 96 | SSIM 1.000 |
| mp4-hevc-no-audio | gif | pass | 2454 |  |
| mp4-2video-2audio | mov | pass | 208 | SSIM 1.000 |
| mp4-2video-2audio | m4a | pass | 250 |  |
| mp3-id3-png-cover | m4a | pass | 33 |  |
| mp3-id3-png-cover | wav | pass | 44 |  |
| mp3-id3-png-cover | flac | pass | 69 |  |
| mp3-id3-png-cover | ogg | pass | 212 |  |
| flac-24bit-96khz | alac | pass | 259 |  |
| flac-24bit-96khz | wav | pass | 132 |  |
| flac-24bit-96khz | mp3 | pass | 125 |  |
| flac-24bit-96khz | m4a | pass | 140 |  |
| flac-6ch-5.1 | m4a | pass | 68 |  |
| flac-6ch-5.1 | alac | pass | 71 |  |
| flac-6ch-5.1 | wav | pass | 36 |  |
| flac-6ch-5.1 | mp3 | pass | 68 |  |
| flac-8ch-7.1 | m4a | pass | 87 |  |
| flac-8ch-7.1 | wav | pass | 34 |  |
| ogg-vorbis-mono | mp3 | pass | 74 |  |
| ogg-vorbis-mono | m4a | pass | 117 |  |
| ogg-vorbis-mono | wav | pass | 161 |  |
| opus-stereo | mp3 | pass | 206 |  |
| opus-stereo | m4a | pass | 144 |  |
| opus-stereo | wav | pass | 122 |  |
| wma-v2 | mp3 | pass | 186 |  |
| wma-v2 | m4a | pass | 132 |  |
| wma-v2 | wav | pass | 223 |  |
| caf-alac | m4a | pass | 38 |  |
| caf-alac | flac | pass | 36 |  |
| caf-alac | wav | pass | 33 |  |
| caf-alac | mp3 | pass | 58 |  |
| pdf-progit-501-pages | png | pass | 95188 |  |
| pdf-progit-501-pages | jpeg | pass | 13688 |  |
| pdf-progit-501-pages | txt | pass | 9987 |  |
| pdf-progit-501-pages | docx | pass | 22227 |  |
| pdf-password-libreoffice | png | pass | 35 |  |
| pdf-password-libreoffice | txt | pass | 38 |  |
| pdf-password-libreoffice | docx | pass | 39 |  |
| pdf-scanned-gutenberg-page | png | pass | 263 |  |
| pdf-scanned-gutenberg-page | jpeg | pass | 67 |  |
| pdf-scanned-gutenberg-page | txt | pass | 4599 |  |
| pdf-scanned-gutenberg-page | docx | pass | 4229 |  |
| pdf-scanned-rotated-4pages | png | pass | 1239 |  |
| pdf-scanned-rotated-4pages | txt | pass | 38964 |  |
| pdf-acroform-irs-1040 | png | pass | 591 |  |
| pdf-acroform-irs-1040 | txt | pass | 160 |  |
| pdf-xfa-dynamic-form | png | pass | 34 |  |
| pdf-xfa-dynamic-form | txt | pass | 35 |  |
| pdf-a1b-ghostscript | png | pass | 328 |  |
| pdf-a1b-ghostscript | txt | pass | 143 |  |
| pdf-a2b-verapdf-pass | png | pass | 187 |  |
| pptx-google-slides-export | pdf | pass | 146 | PDF/A not claimed |
| pptx-google-slides-export | png | pass | 243 |  |
| pptx-google-slides-export | key | skipped |  |  |
| pptx-powerpoint-charts-tables-groups | pdf | pass | 1174 | PDF/A not claimed |
| pptx-powerpoint-charts-tables-groups | png | pass | 3903 |  |
| pptx-powerpoint-charts-tables-groups | odp | pass | 7347 |  |
| xls-biff8-real-world | xlsx | pass | 320 |  |
| xls-biff8-real-world | pdf | pass | 464 | PDF/A not claimed |
| xls-biff8-real-world | csv | pass | 52 |  |
| xls-biff8-real-world | ods | pass | 144 |  |
| xlsx-formulas-merges-charts | pdf | pass | 119 | PDF/A not claimed |
| xlsx-formulas-merges-charts | csv | pass | 102 |  |
| xlsx-formulas-merges-charts | ods | pass | 69 |  |
| xlsx-50000-merged-cells | pdf | pass | 1003 | PDF/A not claimed |
| xlsx-50000-merged-cells | csv | pass | 797 |  |
| docx-images-in-tables | pdf | pass | 361 | PDF/A not claimed |
| docx-images-in-tables | odt | pass | 2240 |  |
| docx-images-in-tables | txt | pass | 88 |  |
| docx-images-in-tables | html | pass | 37 |  |
| docx-chartex | pdf | pass | 35 | PDF/A not claimed |
| docx-chartex | odt | pass | 1895 |  |
| docx-truncated-zip | pdf | pass | 54 |  |
| docx-truncated-zip | txt | pass | 34 |  |
| odt-text-document | pdf | pass | 282 | PDF/A not claimed |
| odt-text-document | docx | pass | 96 |  |
| odt-text-document | txt | pass | 31 |  |
| ods-table-with-title | xlsx | pass | 33 |  |
| ods-table-with-title | pdf | pass | 39 | PDF/A not claimed |
| ods-table-with-title | csv | pass | 35 |  |
| odp-presentation | pptx | pass | 2259 |  |
| odp-presentation | pdf | pass | 1808 | PDF/A not claimed |
| odp-presentation | png | pass | 2100 |  |
| keynote-2013-iwa | pdf | pass | 1424 | PDF/A not claimed |
| keynote-2013-iwa | pptx | pass | 1416 |  |
| keynote-2013-iwa | jpeg | pass | 1433 |  |
| keynote-2018-zipped-bundle | pdf | pass | 1399 | PDF/A not claimed |
| keynote-2018-zipped-bundle | pptx | pass | 1541 |  |
| pages-2013-iwa | pdf | pass | 1459 | PDF/A not claimed |
| pages-2013-iwa | docx | pass | 1382 |  |
| numbers-2013-iwa | pdf | pass | 1491 | PDF/A not claimed |
| numbers-2013-iwa | xlsx | pass | 1483 |  |
| numbers-2013-iwa | csv | pass | 1436 |  |
| zip-nested-office-docs | extract | pass | 169 |  |
| targz-zlib-source | extract | pass | 39 | no checker for . |
| 7z-umlaut-solid | extract | pass | 40 |  |
| 7z-encrypted | extract | pass | 40 |  |
| 7z-data-corrupted | extract | pass | 35 |  |
| rar3-unicode-names | extract | fail | 36 |  |
| rar5-encrypted | extract | pass | 37 |  |
| jpeg-cmyk-adobe | png | pass | 30 | SSIM 1.000 |
| jpeg-cmyk-adobe | pdf | pass | 34 | PDF/A not claimed |
| jpeg-cmyk-adobe | heic | pass | 58 | SSIM 0.996 |
| jpeg-cmyk-adobe | webp | pass | 109 | SSIM 0.990 |
| jpeg-cmyk-small | png | pass | 40 | SSIM 1.000 |
| png-16bit-hdr-room | tiff | pass | 33 | SSIM 1.000 |
| png-16bit-hdr-room | jpeg | pass | 37 | SSIM 0.993 |
| png-16bit-hdr-room | heic | pass | 74 | SSIM 0.995 |
| png-16bit-hdr-room | avif | fail |  |  |
| gif-animated-42-frames | webp | pass | 279 | SSIM 0.969 |
| gif-animated-42-frames | png | pass | 32 | SSIM 1.000 |
| gif-animated-42-frames | heic | pass | 34 | SSIM 0.969 |
| webp-animated-42-frames | gif | pass | 34 | SSIM 1.000 |
| webp-animated-42-frames | png | pass | 36 | SSIM 1.000 |
| avif-10bit-hdr-p3 | jpeg | pass | 421 | SSIM 0.997 |
| avif-10bit-hdr-p3 | png | pass | 3923 | SSIM 1.000 |
| avif-10bit-hdr-p3 | heic | pass | 461 | SSIM 0.999 |
| avif-10bit-hdr-p3 | tiff | pass | 303 | SSIM 1.000 |
| avif-sequence-animated | gif | pass | 191 |  |
| avif-sequence-animated | png | pass | 35 |  |
| tiff-multipage | pdf | pass | 37 | PDF/A not claimed |
| tiff-multipage | png | pass | 35 | SSIM 1.000 |
| tiff-multipage | jpeg | pass | 32 | SSIM 1.000 |
| tiff-ifd-loop | pdf | pass | 32 |  |
| tiff-ifd-loop | png | pass | 20 |  |
| svg-inkscape-filters | png | pass | 10090 | SSIM not measured |
| svg-inkscape-filters | pdf | pass | 9729 | PDF/A not claimed |
| svg-inkscape-filters | jpeg | pass | 6060 | SSIM not measured |
| svg-inkscape-i18n-text | png | pass | 190 | SSIM 0.997 |
| svg-inkscape-i18n-text | pdf | pass | 131 | PDF/A not claimed |
| psd-layer-effects | png | pass | 54 | SSIM 1.000 |
| psd-layer-effects | jpeg | pass | 33 | SSIM 0.998 |
| psd-layer-effects | tiff | pass | 36 | SSIM 1.000 |
| psd-layer-effects | pdf | pass | 41 | PDF/A not claimed |
| psd-cmyk-spot-channels | png | fail | 38 | SSIM 0.424 |
| psd-cmyk-spot-channels | jpeg | pass | 35 | SSIM 1.000 |
| psd-cmyk-spot-channels | tiff | pass | 38 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | jpeg | pass | 81057 | SSIM 0.998 |
| heic-samsung-200mp-gainmap | png | pass | 67740 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | tiff | pass | 64434 | SSIM 1.000 |
| jpeg-exif-orientation-6 | png | pass | 186 | SSIM 1.000 |
| jpeg-exif-orientation-6 | heic | pass | 110 | SSIM 0.997 |
| jpeg-exif-orientation-6 | webp | pass | 295 | SSIM 0.996 |
| jpeg-exif-orientation-6 | pdf | pass | 162 | PDF/A not claimed |
| gif-decompression-bomb | png | pass | 72 |  |
| gif-decompression-bomb | jpeg | pass | 48 |  |
| gen-pdf-500-pages | png | pass | 61724 |  |
| gen-pdf-500-pages | jpeg | pass | 10772 |  |
| gen-pdf-password | png | pass | 175 |  |
| gen-pdf-password | txt | pass | 39 |  |
| gen-zip-truncated | extract | pass | 114 |  |
| gen-name-image | png | pass | 79 | SSIM 1.000 |
| gen-name-image | heic | pass | 67 | SSIM 0.996 |
| gen-name-image | webp | pass | 161 | SSIM 0.990 |
| gen-name-image | tiff | pass | 80 | SSIM 1.000 |
| gen-name-image | gif | pass | 36 | SSIM 0.999 |
| gen-name-image | bmp | pass | 85 | SSIM 1.000 |
| gen-name-image | pdf | pass | 33 | PDF/A not claimed |
| gen-name-video | mp4 | pass | 1257 | SSIM 1.000 |
| gen-name-video | mov | pass | 1253 | SSIM 1.000 |
| gen-name-video | webm | pass | 32382 | SSIM 0.980 |
| gen-name-video | avi | pass | 5183 | SSIM 0.949 |
| gen-name-video | wmv | pass | 5406 | SSIM 0.986 |
| gen-name-video | gif | pass | 19165 |  |
| gen-name-video | mp3 | pass | 687 |  |
| gen-name-video | m4a | pass | 1361 |  |
| gen-name-pdf | png | pass | 85261 |  |
| gen-name-pdf | jpeg | pass | 14353 |  |
| gen-name-pdf | docx | pass | 17745 |  |
| gen-name-pdf | txt | pass | 8017 |  |
| gen-name-pdf | markdown | pass | 7761 |  |
| gen-name-pdf | rtf | pass | 8086 |  |
| gen-name-pdf | html | pass | 17749 |  |
| gen-name-pdf | epub | pass | 17467 |  |
| gen-name-pdf | pptx | pass | 27847 |  |
| gen-name-pdf | xlsx | pass | 8584 |  |
| gen-name-audio | m4a | pass | 49 |  |
| gen-name-audio | wav | pass | 33 |  |
| gen-name-audio | aiff | pass | 33 |  |
| gen-name-audio | flac | pass | 38 |  |
| gen-name-audio | ogg | pass | 287 |  |
| gen-name-audio | opus | pass | 291 |  |
| gen-name-audio | wma | pass | 248 |  |
| gen-name-audio | alac | pass | 27 |  |
| gen-icloud-stub | png | pass |  |  |
