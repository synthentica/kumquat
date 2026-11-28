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
| webm-av1 | mp4 | fail | error: webm-av1.webm: ffmpeg: IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver | 671 |
| webm-av1 | gif | fail | error: webm-av1.webm: ffmpeg: [out#0/gif @ 0x600000734540] Error writing trailer: Invalid argument | 199 |
| asf-wmv-msmpeg4-wma | mp4 | fail | asf-wmv-msmpeg4-wma.mp4: SSIM 0.847 < 0.90 | 489 |
| pptx-google-slides-export | key | skipped | no app on this Mac writes Keynote |  |
| rar3-unicode-names | extract | fail | error: rar3-unicode-names.rar: tar: tar: Error exit delayed from previous errors. | 201 |
| png-16bit-hdr-room | avif | fail | not-offered |  |
| psd-cmyk-spot-channels | png | fail | psd-cmyk-spot-channels.png: SSIM 0.424 < 0.95 | 27 |

## Every conversion

| File | Target | Verdict | ms | Notes |
| --- | --- | --- | ---: | --- |
| heic-iphone13pro-hdr-gainmap | jpeg | pass | 323 | SSIM 0.998 |
| heic-iphone13pro-hdr-gainmap | png | pass | 746 | SSIM 1.000 |
| heic-iphone13pro-hdr-gainmap | avif | fail |  |  |
| heic-iphone13pro-hdr-gainmap | tiff | pass | 302 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | jpeg | pass | 306 | SSIM 0.999 |
| heic-iphone11pro-livephoto-still | png | pass | 2971 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | tiff | pass | 1667 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | pdf | pass | 3302 | PDF/A not claimed |
| heic-iphone8-ios11 | jpeg | pass | 105 | SSIM 0.999 |
| heic-iphone8-ios11 | png | pass | 2381 | SSIM 1.000 |
| heic-visionpro-spatial-stereo | jpeg | pass | 230 | SSIM 0.999 |
| heic-visionpro-spatial-stereo | png | pass | 897 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp4 | pass | 489 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | hevc | pass | 7210 | SSIM 0.995 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | gif | pass | 42129 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp3 | pass | 619 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | m4a | pass | 33 |  |
| mov-iphone14pro-livephoto-video | mp4 | pass | 66 | SSIM 1.000 |
| mov-iphone14pro-livephoto-video | gif | pass | 2730 |  |
| mov-iphone14pro-livephoto-video | snapshot | pass | 243 |  |
| mov-iphoneX-h264-rotated-vfr | mp4 | pass | 62 | SSIM 1.000 |
| mov-iphoneX-h264-rotated-vfr | gif | pass | 4112 |  |
| mov-iphoneX-h264-rotated-vfr | m4a | pass | 306 |  |
| mp4-dolbyvision-profile8.1 | mov | pass | 50 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | hevc | pass | 35 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | gif | pass | 1368 |  |
| mp4-dolbyvision-profile5 | mov | pass | 135 | SSIM 1.000 |
| mp4-dolbyvision-profile5 | hevc | pass | 926 | SSIM 0.992 |
| mp4-hevc-hdr10-pq | mov | pass | 111 | SSIM 1.000 |
| mp4-hevc-hdr10-pq | webm | pass | 4180 | SSIM 0.951 |
| mp4-obs-screen-recording-vfr | mov | pass | 78 | SSIM 1.000 |
| mp4-obs-screen-recording-vfr | gif | pass | 2805 |  |
| mp4-obs-screen-recording-vfr | m4a | pass | 51 |  |
| mkv-multi-audio-8-subtitles | mp4 | pass | 1267 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | mov | pass | 1199 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | m4a | pass | 1095 |  |
| webm-vp9-720p | mp4 | pass | 2527 | SSIM 0.951 |
| webm-vp9-720p | gif | pass | 2478 |  |
| webm-av1 | mp4 | fail | 671 |  |
| webm-av1 | gif | fail | 199 |  |
| webm-multitrack-3video-2audio | mp4 | pass | 3003 | SSIM 1.000 |
| avi-canon-mjpeg-pcm | mp4 | pass | 550 | SSIM 0.980 |
| avi-canon-mjpeg-pcm | gif | pass | 1304 |  |
| avi-canon-mjpeg-pcm | m4a | pass | 222 |  |
| avi-mpeg4-asp-ac3 | mp4 | pass | 388 | SSIM 0.980 |
| avi-mpeg4-asp-ac3 | m4a | pass | 342 |  |
| asf-wmv-msmpeg4-wma | mp4 | fail | 489 | SSIM 0.847 |
| asf-wmv-msmpeg4-wma | m4a | pass | 159 |  |
| asf-wmv-msmpeg4-wma | mp3 | pass | 303 |  |
| mkv-wmv2-vorbis | mp4 | pass | 564 | SSIM 0.954 |
| mkv-wmv2-vorbis | m4a | pass | 312 |  |
| mp4-h264-high10 | mov | pass | 35 | SSIM 1.000 |
| mp4-android-rotated-90 | mov | pass | 51 | SSIM 1.000 |
| mp4-android-rotated-90 | gif | pass | 2209 |  |
| mp4-hevc-no-audio | mov | pass | 28 | SSIM 1.000 |
| mp4-hevc-no-audio | gif | pass | 1494 |  |
| mp4-2video-2audio | mov | pass | 126 | SSIM 1.000 |
| mp4-2video-2audio | m4a | pass | 176 |  |
| mp3-id3-png-cover | m4a | pass | 28 |  |
| mp3-id3-png-cover | wav | pass | 82 |  |
| mp3-id3-png-cover | flac | pass | 73 |  |
| mp3-id3-png-cover | ogg | pass | 266 |  |
| flac-24bit-96khz | alac | pass | 135 |  |
| flac-24bit-96khz | wav | pass | 102 |  |
| flac-24bit-96khz | mp3 | pass | 250 |  |
| flac-24bit-96khz | m4a | pass | 78 |  |
| flac-6ch-5.1 | m4a | pass | 51 |  |
| flac-6ch-5.1 | alac | pass | 49 |  |
| flac-6ch-5.1 | wav | pass | 72 |  |
| flac-6ch-5.1 | mp3 | pass | 128 |  |
| flac-8ch-7.1 | m4a | pass | 67 |  |
| flac-8ch-7.1 | wav | pass | 29 |  |
| ogg-vorbis-mono | mp3 | pass | 34 |  |
| ogg-vorbis-mono | m4a | pass | 147 |  |
| ogg-vorbis-mono | wav | pass | 76 |  |
| opus-stereo | mp3 | pass | 146 |  |
| opus-stereo | m4a | pass | 90 |  |
| opus-stereo | wav | pass | 34 |  |
| wma-v2 | mp3 | pass | 36 |  |
| wma-v2 | m4a | pass | 35 |  |
| wma-v2 | wav | pass | 29 |  |
| caf-alac | m4a | pass | 90 |  |
| caf-alac | flac | pass | 110 |  |
| caf-alac | wav | pass | 114 |  |
| caf-alac | mp3 | pass | 71 |  |
| pdf-progit-501-pages | png | pass | 71692 |  |
| pdf-progit-501-pages | jpeg | pass | 10528 |  |
| pdf-progit-501-pages | txt | pass | 8164 |  |
| pdf-progit-501-pages | docx | pass | 15459 |  |
| pdf-password-libreoffice | png | pass | 144 |  |
| pdf-password-libreoffice | txt | pass | 155 |  |
| pdf-password-libreoffice | docx | pass | 76 |  |
| pdf-scanned-gutenberg-page | png | pass | 239 |  |
| pdf-scanned-gutenberg-page | jpeg | pass | 66 |  |
| pdf-scanned-gutenberg-page | txt | pass | 2998 |  |
| pdf-scanned-gutenberg-page | docx | pass | 2891 |  |
| pdf-scanned-rotated-4pages | png | pass | 885 |  |
| pdf-scanned-rotated-4pages | txt | pass | 27784 |  |
| pdf-acroform-irs-1040 | png | pass | 397 |  |
| pdf-acroform-irs-1040 | txt | pass | 106 |  |
| pdf-xfa-dynamic-form | png | pass | 179 |  |
| pdf-xfa-dynamic-form | txt | pass | 180 |  |
| pdf-a1b-ghostscript | png | pass | 288 |  |
| pdf-a1b-ghostscript | txt | pass | 103 |  |
| pdf-a2b-verapdf-pass | png | pass | 136 |  |
| pptx-google-slides-export | pdf | pass | 127 | PDF/A not claimed |
| pptx-google-slides-export | png | pass | 169 |  |
| pptx-google-slides-export | key | skipped |  |  |
| pptx-powerpoint-charts-tables-groups | pdf | pass | 835 | PDF/A not claimed |
| pptx-powerpoint-charts-tables-groups | png | pass | 2946 |  |
| pptx-powerpoint-charts-tables-groups | odp | pass | 5443 |  |
| xls-biff8-real-world | xlsx | pass | 275 |  |
| xls-biff8-real-world | pdf | pass | 570 | PDF/A not claimed |
| xls-biff8-real-world | csv | pass | 43 |  |
| xls-biff8-real-world | ods | pass | 87 |  |
| xlsx-formulas-merges-charts | pdf | pass | 54 | PDF/A not claimed |
| xlsx-formulas-merges-charts | csv | pass | 145 |  |
| xlsx-formulas-merges-charts | ods | pass | 324 |  |
| xlsx-50000-merged-cells | pdf | pass | 750 | PDF/A not claimed |
| xlsx-50000-merged-cells | csv | pass | 605 |  |
| docx-images-in-tables | pdf | pass | 377 | PDF/A not claimed |
| docx-images-in-tables | odt | pass | 1934 |  |
| docx-images-in-tables | txt | pass | 167 |  |
| docx-images-in-tables | html | pass | 165 |  |
| docx-chartex | pdf | pass | 54 | PDF/A not claimed |
| docx-chartex | odt | pass | 1611 |  |
| docx-truncated-zip | pdf | pass | 57 |  |
| docx-truncated-zip | txt | pass | 38 |  |
| odt-text-document | pdf | pass | 135 | PDF/A not claimed |
| odt-text-document | docx | pass | 35 |  |
| odt-text-document | txt | pass | 33 |  |
| ods-table-with-title | xlsx | pass | 113 |  |
| ods-table-with-title | pdf | pass | 34 | PDF/A not claimed |
| ods-table-with-title | csv | pass | 41 |  |
| odp-presentation | pptx | pass | 1602 |  |
| odp-presentation | pdf | pass | 1710 | PDF/A not claimed |
| odp-presentation | png | pass | 1872 |  |
| keynote-2013-iwa | pdf | pass | 1324 | PDF/A not claimed |
| keynote-2013-iwa | pptx | pass | 1441 |  |
| keynote-2013-iwa | jpeg | pass | 1250 |  |
| keynote-2018-zipped-bundle | pdf | pass | 1371 | PDF/A not claimed |
| keynote-2018-zipped-bundle | pptx | pass | 1261 |  |
| pages-2013-iwa | pdf | pass | 1402 | PDF/A not claimed |
| pages-2013-iwa | docx | pass | 1433 |  |
| numbers-2013-iwa | pdf | pass | 1449 | PDF/A not claimed |
| numbers-2013-iwa | xlsx | pass | 1465 |  |
| numbers-2013-iwa | csv | pass | 1504 |  |
| zip-nested-office-docs | extract | pass | 150 |  |
| targz-zlib-source | extract | pass | 36 | no checker for . |
| 7z-umlaut-solid | extract | pass | 36 |  |
| 7z-encrypted | extract | pass | 167 |  |
| 7z-data-corrupted | extract | pass | 195 |  |
| rar3-unicode-names | extract | fail | 201 |  |
| rar5-encrypted | extract | pass | 106 |  |
| jpeg-cmyk-adobe | png | pass | 99 | SSIM 1.000 |
| jpeg-cmyk-adobe | pdf | pass | 105 | PDF/A not claimed |
| jpeg-cmyk-adobe | heic | pass | 109 | SSIM 0.996 |
| jpeg-cmyk-adobe | webp | pass | 211 | SSIM 0.990 |
| jpeg-cmyk-small | png | pass | 101 | SSIM 1.000 |
| png-16bit-hdr-room | tiff | pass | 59 | SSIM 1.000 |
| png-16bit-hdr-room | jpeg | pass | 34 | SSIM 0.993 |
| png-16bit-hdr-room | heic | pass | 67 | SSIM 0.995 |
| png-16bit-hdr-room | avif | fail |  |  |
| gif-animated-42-frames | webp | pass | 481 | SSIM 0.969 |
| gif-animated-42-frames | png | pass | 32 | SSIM 1.000 |
| gif-animated-42-frames | heic | pass | 59 | SSIM 0.969 |
| webp-animated-42-frames | gif | pass | 118 | SSIM 1.000 |
| webp-animated-42-frames | png | pass | 30 | SSIM 1.000 |
| avif-10bit-hdr-p3 | jpeg | pass | 318 | SSIM 0.997 |
| avif-10bit-hdr-p3 | png | pass | 3637 | SSIM 1.000 |
| avif-10bit-hdr-p3 | heic | pass | 370 | SSIM 0.999 |
| avif-10bit-hdr-p3 | tiff | pass | 622 | SSIM 1.000 |
| avif-sequence-animated | gif | pass | 192 |  |
| avif-sequence-animated | png | pass | 35 |  |
| tiff-multipage | pdf | pass | 41 | PDF/A not claimed |
| tiff-multipage | png | pass | 41 | SSIM 1.000 |
| tiff-multipage | jpeg | pass | 41 | SSIM 1.000 |
| tiff-ifd-loop | pdf | pass | 35 |  |
| tiff-ifd-loop | png | pass | 33 |  |
| svg-inkscape-filters | png | pass | 12409 | SSIM not measured |
| svg-inkscape-filters | pdf | pass | 10577 | PDF/A not claimed |
| svg-inkscape-filters | jpeg | pass | 6400 | SSIM not measured |
| svg-inkscape-i18n-text | png | pass | 232 | SSIM 0.997 |
| svg-inkscape-i18n-text | pdf | pass | 97 | PDF/A not claimed |
| psd-layer-effects | png | pass | 42 | SSIM 1.000 |
| psd-layer-effects | jpeg | pass | 101 | SSIM 0.998 |
| psd-layer-effects | tiff | pass | 180 | SSIM 1.000 |
| psd-layer-effects | pdf | pass | 60 | PDF/A not claimed |
| psd-cmyk-spot-channels | png | fail | 27 | SSIM 0.424 |
| psd-cmyk-spot-channels | jpeg | pass | 20 | SSIM 1.000 |
| psd-cmyk-spot-channels | tiff | pass | 153 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | jpeg | pass | 62812 | SSIM 0.998 |
| heic-samsung-200mp-gainmap | png | pass | 58681 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | tiff | pass | 62920 | SSIM 1.000 |
| jpeg-exif-orientation-6 | png | pass | 186 | SSIM 1.000 |
| jpeg-exif-orientation-6 | heic | pass | 114 | SSIM 0.997 |
| jpeg-exif-orientation-6 | webp | pass | 321 | SSIM 0.996 |
| jpeg-exif-orientation-6 | pdf | pass | 183 | PDF/A not claimed |
| gif-decompression-bomb | png | pass | 144 |  |
| gif-decompression-bomb | jpeg | pass | 159 |  |
| gen-pdf-500-pages | png | pass | 58558 |  |
| gen-pdf-500-pages | jpeg | pass | 5761 |  |
| gen-pdf-password | png | pass | 146 |  |
| gen-pdf-password | txt | pass | 110 |  |
| gen-zip-truncated | extract | pass | 106 |  |
| gen-name-image | png | pass | 83 | SSIM 1.000 |
| gen-name-image | heic | pass | 53 | SSIM 0.996 |
| gen-name-image | webp | pass | 58 | SSIM 0.990 |
| gen-name-image | tiff | pass | 45 | SSIM 1.000 |
| gen-name-image | gif | pass | 144 | SSIM 0.999 |
| gen-name-image | bmp | pass | 30 | SSIM 1.000 |
| gen-name-image | pdf | pass | 180 | PDF/A not claimed |
| gen-name-video | mp4 | pass | 1140 | SSIM 1.000 |
| gen-name-video | mov | pass | 967 | SSIM 1.000 |
| gen-name-video | webm | pass | 25280 | SSIM 0.980 |
| gen-name-video | avi | pass | 3308 | SSIM 0.949 |
| gen-name-video | wmv | pass | 4252 | SSIM 0.986 |
| gen-name-video | gif | pass | 12879 |  |
| gen-name-video | mp3 | pass | 839 |  |
| gen-name-video | m4a | pass | 1154 |  |
| gen-name-pdf | png | pass | 71024 |  |
| gen-name-pdf | jpeg | pass | 13963 |  |
| gen-name-pdf | docx | pass | 19365 |  |
| gen-name-pdf | txt | pass | 9203 |  |
| gen-name-pdf | markdown | pass | 8177 |  |
| gen-name-pdf | rtf | pass | 8159 |  |
| gen-name-pdf | html | pass | 16657 |  |
| gen-name-pdf | epub | pass | 16093 |  |
| gen-name-pdf | pptx | pass | 23765 |  |
| gen-name-pdf | xlsx | pass | 8117 |  |
| gen-name-audio | m4a | pass | 75 |  |
| gen-name-audio | wav | pass | 71 |  |
| gen-name-audio | aiff | pass | 133 |  |
| gen-name-audio | flac | pass | 45 |  |
| gen-name-audio | ogg | pass | 125 |  |
| gen-name-audio | opus | pass | 44 |  |
| gen-name-audio | wma | pass | 126 |  |
| gen-name-audio | alac | pass | 21 |  |
| gen-icloud-stub | png | pass |  |  |
