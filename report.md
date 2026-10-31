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
| webm-av1 | mp4 | fail | error: webm-av1.webm: ffmpeg: IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver | 735 |
| webm-av1 | gif | fail | error: webm-av1.webm: ffmpeg: [out#0/gif @ 0x60000222c540] Error writing trailer: Invalid argument | 99 |
| asf-wmv-msmpeg4-wma | mp4 | fail | asf-wmv-msmpeg4-wma.mp4: SSIM 0.847 < 0.90 | 617 |
| pptx-google-slides-export | key | skipped | no app on this Mac writes Keynote |  |
| rar3-unicode-names | extract | fail | error: rar3-unicode-names.rar: tar: tar: Error exit delayed from previous errors. | 104 |
| png-16bit-hdr-room | avif | fail | not-offered |  |
| psd-cmyk-spot-channels | png | fail | psd-cmyk-spot-channels.png: SSIM 0.424 < 0.95 | 156 |

## Every conversion

| File | Target | Verdict | ms | Notes |
| --- | --- | --- | ---: | --- |
| heic-iphone13pro-hdr-gainmap | jpeg | pass | 216 | SSIM 0.998 |
| heic-iphone13pro-hdr-gainmap | png | pass | 604 | SSIM 1.000 |
| heic-iphone13pro-hdr-gainmap | avif | fail |  |  |
| heic-iphone13pro-hdr-gainmap | tiff | pass | 175 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | jpeg | pass | 211 | SSIM 0.999 |
| heic-iphone11pro-livephoto-still | png | pass | 1858 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | tiff | pass | 1210 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | pdf | pass | 2565 | PDF/A not claimed |
| heic-iphone8-ios11 | jpeg | pass | 59 | SSIM 0.999 |
| heic-iphone8-ios11 | png | pass | 1555 | SSIM 1.000 |
| heic-visionpro-spatial-stereo | jpeg | pass | 169 | SSIM 0.999 |
| heic-visionpro-spatial-stereo | png | pass | 688 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp4 | pass | 319 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | hevc | pass | 6920 | SSIM 0.995 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | gif | pass | 28720 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp3 | pass | 280 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | m4a | pass | 152 |  |
| mov-iphone14pro-livephoto-video | mp4 | pass | 179 | SSIM 1.000 |
| mov-iphone14pro-livephoto-video | gif | pass | 1922 |  |
| mov-iphone14pro-livephoto-video | snapshot | pass | 212 |  |
| mov-iphoneX-h264-rotated-vfr | mp4 | pass | 32 | SSIM 1.000 |
| mov-iphoneX-h264-rotated-vfr | gif | pass | 3204 |  |
| mov-iphoneX-h264-rotated-vfr | m4a | pass | 174 |  |
| mp4-dolbyvision-profile8.1 | mov | pass | 29 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | hevc | pass | 145 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | gif | pass | 1326 |  |
| mp4-dolbyvision-profile5 | mov | pass | 104 | SSIM 1.000 |
| mp4-dolbyvision-profile5 | hevc | pass | 851 | SSIM 0.992 |
| mp4-hevc-hdr10-pq | mov | pass | 34 | SSIM 1.000 |
| mp4-hevc-hdr10-pq | webm | pass | 2869 | SSIM 0.951 |
| mp4-obs-screen-recording-vfr | mov | pass | 63 | SSIM 1.000 |
| mp4-obs-screen-recording-vfr | gif | pass | 2922 |  |
| mp4-obs-screen-recording-vfr | m4a | pass | 131 |  |
| mkv-multi-audio-8-subtitles | mp4 | pass | 1129 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | mov | pass | 1005 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | m4a | pass | 1080 |  |
| webm-vp9-720p | mp4 | pass | 2663 | SSIM 0.951 |
| webm-vp9-720p | gif | pass | 2374 |  |
| webm-av1 | mp4 | fail | 735 |  |
| webm-av1 | gif | fail | 99 |  |
| webm-multitrack-3video-2audio | mp4 | pass | 2997 | SSIM 1.000 |
| avi-canon-mjpeg-pcm | mp4 | pass | 400 | SSIM 0.980 |
| avi-canon-mjpeg-pcm | gif | pass | 1377 |  |
| avi-canon-mjpeg-pcm | m4a | pass | 456 |  |
| avi-mpeg4-asp-ac3 | mp4 | pass | 238 | SSIM 0.980 |
| avi-mpeg4-asp-ac3 | m4a | pass | 234 |  |
| asf-wmv-msmpeg4-wma | mp4 | fail | 617 | SSIM 0.847 |
| asf-wmv-msmpeg4-wma | m4a | pass | 323 |  |
| asf-wmv-msmpeg4-wma | mp3 | pass | 202 |  |
| mkv-wmv2-vorbis | mp4 | pass | 237 | SSIM 0.954 |
| mkv-wmv2-vorbis | m4a | pass | 285 |  |
| mp4-h264-high10 | mov | pass | 32 | SSIM 1.000 |
| mp4-android-rotated-90 | mov | pass | 25 | SSIM 1.000 |
| mp4-android-rotated-90 | gif | pass | 2122 |  |
| mp4-hevc-no-audio | mov | pass | 39 | SSIM 1.000 |
| mp4-hevc-no-audio | gif | pass | 1567 |  |
| mp4-2video-2audio | mov | pass | 123 | SSIM 1.000 |
| mp4-2video-2audio | m4a | pass | 180 |  |
| mp3-id3-png-cover | m4a | pass | 25 |  |
| mp3-id3-png-cover | wav | pass | 155 |  |
| mp3-id3-png-cover | flac | pass | 102 |  |
| mp3-id3-png-cover | ogg | pass | 111 |  |
| flac-24bit-96khz | alac | pass | 122 |  |
| flac-24bit-96khz | wav | pass | 46 |  |
| flac-24bit-96khz | mp3 | pass | 95 |  |
| flac-24bit-96khz | m4a | pass | 78 |  |
| flac-6ch-5.1 | m4a | pass | 53 |  |
| flac-6ch-5.1 | alac | pass | 46 |  |
| flac-6ch-5.1 | wav | pass | 33 |  |
| flac-6ch-5.1 | mp3 | pass | 202 |  |
| flac-8ch-7.1 | m4a | pass | 140 |  |
| flac-8ch-7.1 | wav | pass | 111 |  |
| ogg-vorbis-mono | mp3 | pass | 110 |  |
| ogg-vorbis-mono | m4a | pass | 102 |  |
| ogg-vorbis-mono | wav | pass | 105 |  |
| opus-stereo | mp3 | pass | 103 |  |
| opus-stereo | m4a | pass | 108 |  |
| opus-stereo | wav | pass | 109 |  |
| wma-v2 | mp3 | pass | 203 |  |
| wma-v2 | m4a | pass | 107 |  |
| wma-v2 | wav | pass | 53 |  |
| caf-alac | m4a | pass | 26 |  |
| caf-alac | flac | pass | 174 |  |
| caf-alac | wav | pass | 72 |  |
| caf-alac | mp3 | pass | 169 |  |
| pdf-progit-501-pages | png | pass | 68521 |  |
| pdf-progit-501-pages | jpeg | pass | 12854 |  |
| pdf-progit-501-pages | txt | pass | 8084 |  |
| pdf-progit-501-pages | docx | pass | 16079 |  |
| pdf-password-libreoffice | png | pass | 82 |  |
| pdf-password-libreoffice | txt | pass | 108 |  |
| pdf-password-libreoffice | docx | pass | 165 |  |
| pdf-scanned-gutenberg-page | png | pass | 239 |  |
| pdf-scanned-gutenberg-page | jpeg | pass | 67 |  |
| pdf-scanned-gutenberg-page | txt | pass | 3326 |  |
| pdf-scanned-gutenberg-page | docx | pass | 3468 |  |
| pdf-scanned-rotated-4pages | png | pass | 1042 |  |
| pdf-scanned-rotated-4pages | txt | pass | 33724 |  |
| pdf-acroform-irs-1040 | png | pass | 557 |  |
| pdf-acroform-irs-1040 | txt | pass | 212 |  |
| pdf-xfa-dynamic-form | png | pass | 104 |  |
| pdf-xfa-dynamic-form | txt | pass | 101 |  |
| pdf-a1b-ghostscript | png | pass | 302 |  |
| pdf-a1b-ghostscript | txt | pass | 102 |  |
| pdf-a2b-verapdf-pass | png | pass | 160 |  |
| pptx-google-slides-export | pdf | pass | 180 | PDF/A not claimed |
| pptx-google-slides-export | png | pass | 203 |  |
| pptx-google-slides-export | key | skipped |  |  |
| pptx-powerpoint-charts-tables-groups | pdf | pass | 926 | PDF/A not claimed |
| pptx-powerpoint-charts-tables-groups | png | pass | 3350 |  |
| pptx-powerpoint-charts-tables-groups | odp | pass | 6137 |  |
| xls-biff8-real-world | xlsx | pass | 211 |  |
| xls-biff8-real-world | pdf | pass | 478 | PDF/A not claimed |
| xls-biff8-real-world | csv | pass | 40 |  |
| xls-biff8-real-world | ods | pass | 178 |  |
| xlsx-formulas-merges-charts | pdf | pass | 192 | PDF/A not claimed |
| xlsx-formulas-merges-charts | csv | pass | 50 |  |
| xlsx-formulas-merges-charts | ods | pass | 75 |  |
| xlsx-50000-merged-cells | pdf | pass | 698 | PDF/A not claimed |
| xlsx-50000-merged-cells | csv | pass | 699 |  |
| docx-images-in-tables | pdf | pass | 408 | PDF/A not claimed |
| docx-images-in-tables | odt | pass | 1875 |  |
| docx-images-in-tables | txt | pass | 37 |  |
| docx-images-in-tables | html | pass | 24 |  |
| docx-chartex | pdf | pass | 24 | PDF/A not claimed |
| docx-chartex | odt | pass | 3038 |  |
| docx-truncated-zip | pdf | pass | 92 |  |
| docx-truncated-zip | txt | pass | 71 |  |
| odt-text-document | pdf | pass | 219 | PDF/A not claimed |
| odt-text-document | docx | pass | 98 |  |
| odt-text-document | txt | pass | 114 |  |
| ods-table-with-title | xlsx | pass | 354 |  |
| ods-table-with-title | pdf | pass | 49 | PDF/A not claimed |
| ods-table-with-title | csv | pass | 25 |  |
| odp-presentation | pptx | pass | 1577 |  |
| odp-presentation | pdf | pass | 1528 | PDF/A not claimed |
| odp-presentation | png | pass | 1674 |  |
| keynote-2013-iwa | pdf | pass | 1239 | PDF/A not claimed |
| keynote-2013-iwa | pptx | pass | 1465 |  |
| keynote-2013-iwa | jpeg | pass | 1296 |  |
| keynote-2018-zipped-bundle | pdf | pass | 1358 | PDF/A not claimed |
| keynote-2018-zipped-bundle | pptx | pass | 1441 |  |
| pages-2013-iwa | pdf | pass | 1527 | PDF/A not claimed |
| pages-2013-iwa | docx | pass | 1216 |  |
| numbers-2013-iwa | pdf | pass | 1564 | PDF/A not claimed |
| numbers-2013-iwa | xlsx | pass | 1211 |  |
| numbers-2013-iwa | csv | pass | 1222 |  |
| zip-nested-office-docs | extract | pass | 26 |  |
| targz-zlib-source | extract | pass | 28 | no checker for . |
| 7z-umlaut-solid | extract | pass | 170 |  |
| 7z-encrypted | extract | pass | 247 |  |
| 7z-data-corrupted | extract | pass | 98 |  |
| rar3-unicode-names | extract | fail | 104 |  |
| rar5-encrypted | extract | pass | 99 |  |
| jpeg-cmyk-adobe | png | pass | 101 | SSIM 1.000 |
| jpeg-cmyk-adobe | pdf | pass | 102 | PDF/A not claimed |
| jpeg-cmyk-adobe | heic | pass | 109 | SSIM 0.996 |
| jpeg-cmyk-adobe | webp | pass | 204 | SSIM 0.990 |
| jpeg-cmyk-small | png | pass | 109 | SSIM 1.000 |
| png-16bit-hdr-room | tiff | pass | 61 | SSIM 1.000 |
| png-16bit-hdr-room | jpeg | pass | 44 | SSIM 0.993 |
| png-16bit-hdr-room | heic | pass | 72 | SSIM 0.995 |
| png-16bit-hdr-room | avif | fail |  |  |
| gif-animated-42-frames | webp | pass | 376 | SSIM 0.969 |
| gif-animated-42-frames | png | pass | 69 | SSIM 1.000 |
| gif-animated-42-frames | heic | pass | 54 | SSIM 0.969 |
| webp-animated-42-frames | gif | pass | 29 | SSIM 1.000 |
| webp-animated-42-frames | png | pass | 31 | SSIM 1.000 |
| avif-10bit-hdr-p3 | jpeg | pass | 387 | SSIM 0.997 |
| avif-10bit-hdr-p3 | png | pass | 3629 | SSIM 1.000 |
| avif-10bit-hdr-p3 | heic | pass | 398 | SSIM 0.999 |
| avif-10bit-hdr-p3 | tiff | pass | 399 | SSIM 1.000 |
| avif-sequence-animated | gif | pass | 153 |  |
| avif-sequence-animated | png | pass | 34 |  |
| tiff-multipage | pdf | pass | 143 | PDF/A not claimed |
| tiff-multipage | png | pass | 120 | SSIM 1.000 |
| tiff-multipage | jpeg | pass | 116 | SSIM 1.000 |
| tiff-ifd-loop | pdf | pass | 39 |  |
| tiff-ifd-loop | png | pass | 154 |  |
| svg-inkscape-filters | png | pass | 10806 | SSIM not measured |
| svg-inkscape-filters | pdf | pass | 9405 | PDF/A not claimed |
| svg-inkscape-filters | jpeg | pass | 5258 | SSIM not measured |
| svg-inkscape-i18n-text | png | pass | 187 | SSIM 0.997 |
| svg-inkscape-i18n-text | pdf | pass | 90 | PDF/A not claimed |
| psd-layer-effects | png | pass | 41 | SSIM 1.000 |
| psd-layer-effects | jpeg | pass | 139 | SSIM 0.998 |
| psd-layer-effects | tiff | pass | 73 | SSIM 1.000 |
| psd-layer-effects | pdf | pass | 54 | PDF/A not claimed |
| psd-cmyk-spot-channels | png | fail | 156 | SSIM 0.424 |
| psd-cmyk-spot-channels | jpeg | pass | 35 | SSIM 1.000 |
| psd-cmyk-spot-channels | tiff | pass | 40 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | jpeg | pass | 60954 | SSIM 0.998 |
| heic-samsung-200mp-gainmap | png | pass | 57633 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | tiff | pass | 56864 | SSIM 1.000 |
| jpeg-exif-orientation-6 | png | pass | 168 | SSIM 1.000 |
| jpeg-exif-orientation-6 | heic | pass | 76 | SSIM 0.997 |
| jpeg-exif-orientation-6 | webp | pass | 304 | SSIM 0.996 |
| jpeg-exif-orientation-6 | pdf | pass | 153 | PDF/A not claimed |
| gif-decompression-bomb | png | pass | 145 |  |
| gif-decompression-bomb | jpeg | pass | 25 |  |
| gen-pdf-500-pages | png | pass | 59342 |  |
| gen-pdf-500-pages | jpeg | pass | 5563 |  |
| gen-pdf-password | png | pass | 127 |  |
| gen-pdf-password | txt | pass | 161 |  |
| gen-zip-truncated | extract | pass | 74 |  |
| gen-name-image | png | pass | 67 | SSIM 1.000 |
| gen-name-image | heic | pass | 53 | SSIM 0.996 |
| gen-name-image | webp | pass | 86 | SSIM 0.990 |
| gen-name-image | tiff | pass | 172 | SSIM 1.000 |
| gen-name-image | gif | pass | 62 | SSIM 0.999 |
| gen-name-image | bmp | pass | 33 | SSIM 1.000 |
| gen-name-image | pdf | pass | 44 | PDF/A not claimed |
| gen-name-video | mp4 | pass | 1073 | SSIM 1.000 |
| gen-name-video | mov | pass | 1009 | SSIM 1.000 |
| gen-name-video | webm | pass | 27407 | SSIM 0.980 |
| gen-name-video | avi | pass | 5115 | SSIM 0.949 |
| gen-name-video | wmv | pass | 5462 | SSIM 0.986 |
| gen-name-video | gif | pass | 22320 |  |
| gen-name-video | mp3 | pass | 1036 |  |
| gen-name-video | m4a | pass | 1130 |  |
| gen-name-pdf | png | pass | 82690 |  |
| gen-name-pdf | jpeg | pass | 22697 |  |
| gen-name-pdf | docx | pass | 20789 |  |
| gen-name-pdf | txt | pass | 7327 |  |
| gen-name-pdf | markdown | pass | 7654 |  |
| gen-name-pdf | rtf | pass | 8248 |  |
| gen-name-pdf | html | pass | 16747 |  |
| gen-name-pdf | epub | pass | 16700 |  |
| gen-name-pdf | pptx | pass | 26685 |  |
| gen-name-pdf | xlsx | pass | 7348 |  |
| gen-name-audio | m4a | pass | 49 |  |
| gen-name-audio | wav | pass | 40 |  |
| gen-name-audio | aiff | pass | 36 |  |
| gen-name-audio | flac | pass | 171 |  |
| gen-name-audio | ogg | pass | 233 |  |
| gen-name-audio | opus | pass | 52 |  |
| gen-name-audio | wma | pass | 56 |  |
| gen-name-audio | alac | pass | 140 |  |
| gen-icloud-stub | png | pass |  |  |
