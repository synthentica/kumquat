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
| webm-av1 | mp4 | fail | error: webm-av1.webm: ffmpeg: IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver | 795 |
| webm-av1 | gif | fail | error: webm-av1.webm: ffmpeg: [out#0/gif @ 0x600001654540] Error writing trailer: Invalid argument | 300 |
| asf-wmv-msmpeg4-wma | mp4 | fail | asf-wmv-msmpeg4-wma.mp4: SSIM 0.847 < 0.90 | 687 |
| pptx-google-slides-export | key | skipped | no app on this Mac writes Keynote |  |
| rar3-unicode-names | extract | fail | error: rar3-unicode-names.rar: tar: tar: Error exit delayed from previous errors. | 112 |
| png-16bit-hdr-room | avif | fail | not-offered |  |
| psd-cmyk-spot-channels | png | fail | psd-cmyk-spot-channels.png: SSIM 0.424 < 0.95 | 26 |

## Every conversion

| File | Target | Verdict | ms | Notes |
| --- | --- | --- | ---: | --- |
| heic-iphone13pro-hdr-gainmap | jpeg | pass | 249 | SSIM 0.998 |
| heic-iphone13pro-hdr-gainmap | png | pass | 731 | SSIM 1.000 |
| heic-iphone13pro-hdr-gainmap | avif | fail |  |  |
| heic-iphone13pro-hdr-gainmap | tiff | pass | 213 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | jpeg | pass | 270 | SSIM 0.999 |
| heic-iphone11pro-livephoto-still | png | pass | 1886 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | tiff | pass | 1123 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | pdf | pass | 2805 | PDF/A not claimed |
| heic-iphone8-ios11 | jpeg | pass | 70 | SSIM 0.999 |
| heic-iphone8-ios11 | png | pass | 1815 | SSIM 1.000 |
| heic-visionpro-spatial-stereo | jpeg | pass | 211 | SSIM 0.999 |
| heic-visionpro-spatial-stereo | png | pass | 860 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp4 | pass | 268 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | hevc | pass | 7088 | SSIM 0.995 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | gif | pass | 38669 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp3 | pass | 327 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | m4a | pass | 38 |  |
| mov-iphone14pro-livephoto-video | mp4 | pass | 68 | SSIM 1.000 |
| mov-iphone14pro-livephoto-video | gif | pass | 2230 |  |
| mov-iphone14pro-livephoto-video | snapshot | pass | 204 |  |
| mov-iphoneX-h264-rotated-vfr | mp4 | pass | 38 | SSIM 1.000 |
| mov-iphoneX-h264-rotated-vfr | gif | pass | 4667 |  |
| mov-iphoneX-h264-rotated-vfr | m4a | pass | 240 |  |
| mp4-dolbyvision-profile8.1 | mov | pass | 125 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | hevc | pass | 50 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | gif | pass | 1552 |  |
| mp4-dolbyvision-profile5 | mov | pass | 37 | SSIM 1.000 |
| mp4-dolbyvision-profile5 | hevc | pass | 938 | SSIM 0.992 |
| mp4-hevc-hdr10-pq | mov | pass | 32 | SSIM 1.000 |
| mp4-hevc-hdr10-pq | webm | pass | 3660 | SSIM 0.951 |
| mp4-obs-screen-recording-vfr | mov | pass | 75 | SSIM 1.000 |
| mp4-obs-screen-recording-vfr | gif | pass | 2777 |  |
| mp4-obs-screen-recording-vfr | m4a | pass | 142 |  |
| mkv-multi-audio-8-subtitles | mp4 | pass | 1052 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | mov | pass | 1060 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | m4a | pass | 1056 |  |
| webm-vp9-720p | mp4 | pass | 2826 | SSIM 0.951 |
| webm-vp9-720p | gif | pass | 2339 |  |
| webm-av1 | mp4 | fail | 795 |  |
| webm-av1 | gif | fail | 300 |  |
| webm-multitrack-3video-2audio | mp4 | pass | 3287 | SSIM 1.000 |
| avi-canon-mjpeg-pcm | mp4 | pass | 375 | SSIM 0.980 |
| avi-canon-mjpeg-pcm | gif | pass | 1454 |  |
| avi-canon-mjpeg-pcm | m4a | pass | 434 |  |
| avi-mpeg4-asp-ac3 | mp4 | pass | 492 | SSIM 0.980 |
| avi-mpeg4-asp-ac3 | m4a | pass | 423 |  |
| asf-wmv-msmpeg4-wma | mp4 | fail | 687 | SSIM 0.847 |
| asf-wmv-msmpeg4-wma | m4a | pass | 172 |  |
| asf-wmv-msmpeg4-wma | mp3 | pass | 378 |  |
| mkv-wmv2-vorbis | mp4 | pass | 442 | SSIM 0.954 |
| mkv-wmv2-vorbis | m4a | pass | 393 |  |
| mp4-h264-high10 | mov | pass | 44 | SSIM 1.000 |
| mp4-android-rotated-90 | mov | pass | 35 | SSIM 1.000 |
| mp4-android-rotated-90 | gif | pass | 2196 |  |
| mp4-hevc-no-audio | mov | pass | 34 | SSIM 1.000 |
| mp4-hevc-no-audio | gif | pass | 1735 |  |
| mp4-2video-2audio | mov | pass | 139 | SSIM 1.000 |
| mp4-2video-2audio | m4a | pass | 183 |  |
| mp3-id3-png-cover | m4a | pass | 26 |  |
| mp3-id3-png-cover | wav | pass | 22 |  |
| mp3-id3-png-cover | flac | pass | 26 |  |
| mp3-id3-png-cover | ogg | pass | 516 |  |
| flac-24bit-96khz | alac | pass | 127 |  |
| flac-24bit-96khz | wav | pass | 50 |  |
| flac-24bit-96khz | mp3 | pass | 190 |  |
| flac-24bit-96khz | m4a | pass | 84 |  |
| flac-6ch-5.1 | m4a | pass | 55 |  |
| flac-6ch-5.1 | alac | pass | 53 |  |
| flac-6ch-5.1 | wav | pass | 30 |  |
| flac-6ch-5.1 | mp3 | pass | 216 |  |
| flac-8ch-7.1 | m4a | pass | 179 |  |
| flac-8ch-7.1 | wav | pass | 48 |  |
| ogg-vorbis-mono | mp3 | pass | 302 |  |
| ogg-vorbis-mono | m4a | pass | 145 |  |
| ogg-vorbis-mono | wav | pass | 285 |  |
| opus-stereo | mp3 | pass | 59 |  |
| opus-stereo | m4a | pass | 147 |  |
| opus-stereo | wav | pass | 35 |  |
| wma-v2 | mp3 | pass | 23 |  |
| wma-v2 | m4a | pass | 108 |  |
| wma-v2 | wav | pass | 216 |  |
| caf-alac | m4a | pass | 106 |  |
| caf-alac | flac | pass | 122 |  |
| caf-alac | wav | pass | 168 |  |
| caf-alac | mp3 | pass | 103 |  |
| pdf-progit-501-pages | png | pass | 78008 |  |
| pdf-progit-501-pages | jpeg | pass | 10760 |  |
| pdf-progit-501-pages | txt | pass | 7932 |  |
| pdf-progit-501-pages | docx | pass | 14805 |  |
| pdf-password-libreoffice | png | pass | 178 |  |
| pdf-password-libreoffice | txt | pass | 81 |  |
| pdf-password-libreoffice | docx | pass | 41 |  |
| pdf-scanned-gutenberg-page | png | pass | 351 |  |
| pdf-scanned-gutenberg-page | jpeg | pass | 67 |  |
| pdf-scanned-gutenberg-page | txt | pass | 2746 |  |
| pdf-scanned-gutenberg-page | docx | pass | 2797 |  |
| pdf-scanned-rotated-4pages | png | pass | 886 |  |
| pdf-scanned-rotated-4pages | txt | pass | 32070 |  |
| pdf-acroform-irs-1040 | png | pass | 444 |  |
| pdf-acroform-irs-1040 | txt | pass | 163 |  |
| pdf-xfa-dynamic-form | png | pass | 126 |  |
| pdf-xfa-dynamic-form | txt | pass | 134 |  |
| pdf-a1b-ghostscript | png | pass | 309 |  |
| pdf-a1b-ghostscript | txt | pass | 111 |  |
| pdf-a2b-verapdf-pass | png | pass | 147 |  |
| pptx-google-slides-export | pdf | pass | 168 | PDF/A not claimed |
| pptx-google-slides-export | png | pass | 206 |  |
| pptx-google-slides-export | key | skipped |  |  |
| pptx-powerpoint-charts-tables-groups | pdf | pass | 992 | PDF/A not claimed |
| pptx-powerpoint-charts-tables-groups | png | pass | 3138 |  |
| pptx-powerpoint-charts-tables-groups | odp | pass | 5884 |  |
| xls-biff8-real-world | xlsx | pass | 208 |  |
| xls-biff8-real-world | pdf | pass | 430 | PDF/A not claimed |
| xls-biff8-real-world | csv | pass | 169 |  |
| xls-biff8-real-world | ods | pass | 93 |  |
| xlsx-formulas-merges-charts | pdf | pass | 53 | PDF/A not claimed |
| xlsx-formulas-merges-charts | csv | pass | 24 |  |
| xlsx-formulas-merges-charts | ods | pass | 90 |  |
| xlsx-50000-merged-cells | pdf | pass | 700 | PDF/A not claimed |
| xlsx-50000-merged-cells | csv | pass | 730 |  |
| docx-images-in-tables | pdf | pass | 401 | PDF/A not claimed |
| docx-images-in-tables | odt | pass | 2038 |  |
| docx-images-in-tables | txt | pass | 166 |  |
| docx-images-in-tables | html | pass | 127 |  |
| docx-chartex | pdf | pass | 101 | PDF/A not claimed |
| docx-chartex | odt | pass | 2109 |  |
| docx-truncated-zip | pdf | pass | 168 |  |
| docx-truncated-zip | txt | pass | 74 |  |
| odt-text-document | pdf | pass | 249 | PDF/A not claimed |
| odt-text-document | docx | pass | 109 |  |
| odt-text-document | txt | pass | 37 |  |
| ods-table-with-title | xlsx | pass | 196 |  |
| ods-table-with-title | pdf | pass | 26 | PDF/A not claimed |
| ods-table-with-title | csv | pass | 116 |  |
| odp-presentation | pptx | pass | 1726 |  |
| odp-presentation | pdf | pass | 1627 | PDF/A not claimed |
| odp-presentation | png | pass | 1791 |  |
| keynote-2013-iwa | pdf | pass | 1274 | PDF/A not claimed |
| keynote-2013-iwa | pptx | pass | 1403 |  |
| keynote-2013-iwa | jpeg | pass | 1449 |  |
| keynote-2018-zipped-bundle | pdf | pass | 1398 | PDF/A not claimed |
| keynote-2018-zipped-bundle | pptx | pass | 1532 |  |
| pages-2013-iwa | pdf | pass | 1442 | PDF/A not claimed |
| pages-2013-iwa | docx | pass | 1399 |  |
| numbers-2013-iwa | pdf | pass | 1465 | PDF/A not claimed |
| numbers-2013-iwa | xlsx | pass | 1634 |  |
| numbers-2013-iwa | csv | pass | 1640 |  |
| zip-nested-office-docs | extract | pass | 194 |  |
| targz-zlib-source | extract | pass | 144 | no checker for . |
| 7z-umlaut-solid | extract | pass | 51 |  |
| 7z-encrypted | extract | pass | 30 |  |
| 7z-data-corrupted | extract | pass | 26 |  |
| rar3-unicode-names | extract | fail | 112 |  |
| rar5-encrypted | extract | pass | 31 |  |
| jpeg-cmyk-adobe | png | pass | 66 | SSIM 1.000 |
| jpeg-cmyk-adobe | pdf | pass | 132 | PDF/A not claimed |
| jpeg-cmyk-adobe | heic | pass | 91 | SSIM 0.996 |
| jpeg-cmyk-adobe | webp | pass | 438 | SSIM 0.990 |
| jpeg-cmyk-small | png | pass | 60 | SSIM 1.000 |
| png-16bit-hdr-room | tiff | pass | 130 | SSIM 1.000 |
| png-16bit-hdr-room | jpeg | pass | 44 | SSIM 0.993 |
| png-16bit-hdr-room | heic | pass | 66 | SSIM 0.995 |
| png-16bit-hdr-room | avif | fail |  |  |
| gif-animated-42-frames | webp | pass | 295 | SSIM 0.969 |
| gif-animated-42-frames | png | pass | 134 | SSIM 1.000 |
| gif-animated-42-frames | heic | pass | 44 | SSIM 0.969 |
| webp-animated-42-frames | gif | pass | 30 | SSIM 1.000 |
| webp-animated-42-frames | png | pass | 91 | SSIM 1.000 |
| avif-10bit-hdr-p3 | jpeg | pass | 464 | SSIM 0.997 |
| avif-10bit-hdr-p3 | png | pass | 3715 | SSIM 1.000 |
| avif-10bit-hdr-p3 | heic | pass | 451 | SSIM 0.999 |
| avif-10bit-hdr-p3 | tiff | pass | 524 | SSIM 1.000 |
| avif-sequence-animated | gif | pass | 218 |  |
| avif-sequence-animated | png | pass | 38 |  |
| tiff-multipage | pdf | pass | 173 | PDF/A not claimed |
| tiff-multipage | png | pass | 103 | SSIM 1.000 |
| tiff-multipage | jpeg | pass | 154 | SSIM 1.000 |
| tiff-ifd-loop | pdf | pass | 174 |  |
| tiff-ifd-loop | png | pass | 79 |  |
| svg-inkscape-filters | png | pass | 13528 | SSIM not measured |
| svg-inkscape-filters | pdf | pass | 11479 | PDF/A not claimed |
| svg-inkscape-filters | jpeg | pass | 4585 | SSIM not measured |
| svg-inkscape-i18n-text | png | pass | 301 | SSIM 0.997 |
| svg-inkscape-i18n-text | pdf | pass | 83 | PDF/A not claimed |
| psd-layer-effects | png | pass | 46 | SSIM 1.000 |
| psd-layer-effects | jpeg | pass | 146 | SSIM 0.998 |
| psd-layer-effects | tiff | pass | 61 | SSIM 1.000 |
| psd-layer-effects | pdf | pass | 44 | PDF/A not claimed |
| psd-cmyk-spot-channels | png | fail | 26 | SSIM 0.424 |
| psd-cmyk-spot-channels | jpeg | pass | 30 | SSIM 1.000 |
| psd-cmyk-spot-channels | tiff | pass | 133 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | jpeg | pass | 73755 | SSIM 0.998 |
| heic-samsung-200mp-gainmap | png | pass | 68376 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | tiff | pass | 64868 | SSIM 1.000 |
| jpeg-exif-orientation-6 | png | pass | 224 | SSIM 1.000 |
| jpeg-exif-orientation-6 | heic | pass | 116 | SSIM 0.997 |
| jpeg-exif-orientation-6 | webp | pass | 534 | SSIM 0.996 |
| jpeg-exif-orientation-6 | pdf | pass | 211 | PDF/A not claimed |
| gif-decompression-bomb | png | pass | 116 |  |
| gif-decompression-bomb | jpeg | pass | 119 |  |
| gen-pdf-500-pages | png | pass | 71912 |  |
| gen-pdf-500-pages | jpeg | pass | 9098 |  |
| gen-pdf-password | png | pass | 23 |  |
| gen-pdf-password | txt | pass | 130 |  |
| gen-zip-truncated | extract | pass | 144 |  |
| gen-name-image | png | pass | 72 | SSIM 1.000 |
| gen-name-image | heic | pass | 54 | SSIM 0.996 |
| gen-name-image | webp | pass | 214 | SSIM 0.990 |
| gen-name-image | tiff | pass | 29 | SSIM 1.000 |
| gen-name-image | gif | pass | 47 | SSIM 0.999 |
| gen-name-image | bmp | pass | 28 | SSIM 1.000 |
| gen-name-image | pdf | pass | 148 | PDF/A not claimed |
| gen-name-video | mp4 | pass | 1069 | SSIM 1.000 |
| gen-name-video | mov | pass | 1347 | SSIM 1.000 |
| gen-name-video | webm | pass | 36891 | SSIM 0.980 |
| gen-name-video | avi | pass | 5770 | SSIM 0.949 |
| gen-name-video | wmv | pass | 5177 | SSIM 0.986 |
| gen-name-video | gif | pass | 20242 |  |
| gen-name-video | mp3 | pass | 623 |  |
| gen-name-video | m4a | pass | 1390 |  |
| gen-name-pdf | png | pass | 96935 |  |
| gen-name-pdf | jpeg | pass | 19353 |  |
| gen-name-pdf | docx | pass | 20781 |  |
| gen-name-pdf | txt | pass | 9432 |  |
| gen-name-pdf | markdown | pass | 9018 |  |
| gen-name-pdf | rtf | pass | 8470 |  |
| gen-name-pdf | html | pass | 20059 |  |
| gen-name-pdf | epub | pass | 19875 |  |
| gen-name-pdf | pptx | pass | 31056 |  |
| gen-name-pdf | xlsx | pass | 8509 |  |
| gen-name-audio | m4a | pass | 72 |  |
| gen-name-audio | wav | pass | 39 |  |
| gen-name-audio | aiff | pass | 46 |  |
| gen-name-audio | flac | pass | 156 |  |
| gen-name-audio | ogg | pass | 399 |  |
| gen-name-audio | opus | pass | 137 |  |
| gen-name-audio | wma | pass | 298 |  |
| gen-name-audio | alac | pass | 20 |  |
| gen-icloud-stub | png | pass |  |  |
