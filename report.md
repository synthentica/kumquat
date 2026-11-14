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
| webm-av1 | mp4 | fail | error: webm-av1.webm: ffmpeg: IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver | 543 |
| webm-av1 | gif | fail | error: webm-av1.webm: ffmpeg: [out#0/gif @ 0x600001b68540] Error writing trailer: Invalid argument | 125 |
| asf-wmv-msmpeg4-wma | mp4 | fail | asf-wmv-msmpeg4-wma.mp4: SSIM 0.847 < 0.90 | 573 |
| pptx-google-slides-export | key | skipped | no app on this Mac writes Keynote |  |
| rar3-unicode-names | extract | fail | error: rar3-unicode-names.rar: tar: tar: Error exit delayed from previous errors. | 33 |
| png-16bit-hdr-room | avif | fail | not-offered |  |
| psd-cmyk-spot-channels | png | fail | psd-cmyk-spot-channels.png: SSIM 0.424 < 0.95 | 41 |

## Every conversion

| File | Target | Verdict | ms | Notes |
| --- | --- | --- | ---: | --- |
| heic-iphone13pro-hdr-gainmap | jpeg | pass | 216 | SSIM 0.998 |
| heic-iphone13pro-hdr-gainmap | png | pass | 773 | SSIM 1.000 |
| heic-iphone13pro-hdr-gainmap | avif | fail |  |  |
| heic-iphone13pro-hdr-gainmap | tiff | pass | 264 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | jpeg | pass | 128 | SSIM 0.999 |
| heic-iphone11pro-livephoto-still | png | pass | 2198 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | tiff | pass | 1330 | SSIM 1.000 |
| heic-iphone11pro-livephoto-still | pdf | pass | 2803 | PDF/A not claimed |
| heic-iphone8-ios11 | jpeg | pass | 77 | SSIM 0.999 |
| heic-iphone8-ios11 | png | pass | 1935 | SSIM 1.000 |
| heic-visionpro-spatial-stereo | jpeg | pass | 274 | SSIM 0.999 |
| heic-visionpro-spatial-stereo | png | pass | 786 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp4 | pass | 773 | SSIM 1.000 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | hevc | pass | 6952 | SSIM 0.995 |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | gif | pass | 46931 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | mp3 | pass | 400 |  |
| mov-iphone12pro-hevc-hlg-dolbyvision-8.4 | m4a | pass | 42 |  |
| mov-iphone14pro-livephoto-video | mp4 | pass | 53 | SSIM 1.000 |
| mov-iphone14pro-livephoto-video | gif | pass | 3148 |  |
| mov-iphone14pro-livephoto-video | snapshot | pass | 179 |  |
| mov-iphoneX-h264-rotated-vfr | mp4 | pass | 35 | SSIM 1.000 |
| mov-iphoneX-h264-rotated-vfr | gif | pass | 4940 |  |
| mov-iphoneX-h264-rotated-vfr | m4a | pass | 176 |  |
| mp4-dolbyvision-profile8.1 | mov | pass | 34 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | hevc | pass | 54 | SSIM 1.000 |
| mp4-dolbyvision-profile8.1 | gif | pass | 1344 |  |
| mp4-dolbyvision-profile5 | mov | pass | 50 | SSIM 1.000 |
| mp4-dolbyvision-profile5 | hevc | pass | 977 | SSIM 0.992 |
| mp4-hevc-hdr10-pq | mov | pass | 97 | SSIM 1.000 |
| mp4-hevc-hdr10-pq | webm | pass | 4062 | SSIM 0.951 |
| mp4-obs-screen-recording-vfr | mov | pass | 170 | SSIM 1.000 |
| mp4-obs-screen-recording-vfr | gif | pass | 2857 |  |
| mp4-obs-screen-recording-vfr | m4a | pass | 29 |  |
| mkv-multi-audio-8-subtitles | mp4 | pass | 964 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | mov | pass | 975 | SSIM 1.000 |
| mkv-multi-audio-8-subtitles | m4a | pass | 1161 |  |
| webm-vp9-720p | mp4 | pass | 2717 | SSIM 0.951 |
| webm-vp9-720p | gif | pass | 2277 |  |
| webm-av1 | mp4 | fail | 543 |  |
| webm-av1 | gif | fail | 125 |  |
| webm-multitrack-3video-2audio | mp4 | pass | 3072 | SSIM 1.000 |
| avi-canon-mjpeg-pcm | mp4 | pass | 729 | SSIM 0.980 |
| avi-canon-mjpeg-pcm | gif | pass | 1401 |  |
| avi-canon-mjpeg-pcm | m4a | pass | 72 |  |
| avi-mpeg4-asp-ac3 | mp4 | pass | 322 | SSIM 0.980 |
| avi-mpeg4-asp-ac3 | m4a | pass | 201 |  |
| asf-wmv-msmpeg4-wma | mp4 | fail | 573 | SSIM 0.847 |
| asf-wmv-msmpeg4-wma | m4a | pass | 137 |  |
| asf-wmv-msmpeg4-wma | mp3 | pass | 150 |  |
| mkv-wmv2-vorbis | mp4 | pass | 504 | SSIM 0.954 |
| mkv-wmv2-vorbis | m4a | pass | 301 |  |
| mp4-h264-high10 | mov | pass | 120 | SSIM 1.000 |
| mp4-android-rotated-90 | mov | pass | 199 | SSIM 1.000 |
| mp4-android-rotated-90 | gif | pass | 2524 |  |
| mp4-hevc-no-audio | mov | pass | 33 | SSIM 1.000 |
| mp4-hevc-no-audio | gif | pass | 2225 |  |
| mp4-2video-2audio | mov | pass | 201 | SSIM 1.000 |
| mp4-2video-2audio | m4a | pass | 206 |  |
| mp3-id3-png-cover | m4a | pass | 57 |  |
| mp3-id3-png-cover | wav | pass | 35 |  |
| mp3-id3-png-cover | flac | pass | 37 |  |
| mp3-id3-png-cover | ogg | pass | 49 |  |
| flac-24bit-96khz | alac | pass | 224 |  |
| flac-24bit-96khz | wav | pass | 110 |  |
| flac-24bit-96khz | mp3 | pass | 198 |  |
| flac-24bit-96khz | m4a | pass | 103 |  |
| flac-6ch-5.1 | m4a | pass | 85 |  |
| flac-6ch-5.1 | alac | pass | 105 |  |
| flac-6ch-5.1 | wav | pass | 107 |  |
| flac-6ch-5.1 | mp3 | pass | 210 |  |
| flac-8ch-7.1 | m4a | pass | 140 |  |
| flac-8ch-7.1 | wav | pass | 35 |  |
| ogg-vorbis-mono | mp3 | pass | 54 |  |
| ogg-vorbis-mono | m4a | pass | 55 |  |
| ogg-vorbis-mono | wav | pass | 186 |  |
| opus-stereo | mp3 | pass | 139 |  |
| opus-stereo | m4a | pass | 165 |  |
| opus-stereo | wav | pass | 55 |  |
| wma-v2 | mp3 | pass | 153 |  |
| wma-v2 | m4a | pass | 60 |  |
| wma-v2 | wav | pass | 50 |  |
| caf-alac | m4a | pass | 32 |  |
| caf-alac | flac | pass | 37 |  |
| caf-alac | wav | pass | 32 |  |
| caf-alac | mp3 | pass | 38 |  |
| pdf-progit-501-pages | png | pass | 87047 |  |
| pdf-progit-501-pages | jpeg | pass | 11284 |  |
| pdf-progit-501-pages | txt | pass | 7945 |  |
| pdf-progit-501-pages | docx | pass | 18612 |  |
| pdf-password-libreoffice | png | pass | 31 |  |
| pdf-password-libreoffice | txt | pass | 35 |  |
| pdf-password-libreoffice | docx | pass | 34 |  |
| pdf-scanned-gutenberg-page | png | pass | 267 |  |
| pdf-scanned-gutenberg-page | jpeg | pass | 70 |  |
| pdf-scanned-gutenberg-page | txt | pass | 3717 |  |
| pdf-scanned-gutenberg-page | docx | pass | 3619 |  |
| pdf-scanned-rotated-4pages | png | pass | 1211 |  |
| pdf-scanned-rotated-4pages | txt | pass | 37822 |  |
| pdf-acroform-irs-1040 | png | pass | 465 |  |
| pdf-acroform-irs-1040 | txt | pass | 130 |  |
| pdf-xfa-dynamic-form | png | pass | 44 |  |
| pdf-xfa-dynamic-form | txt | pass | 36 |  |
| pdf-a1b-ghostscript | png | pass | 268 |  |
| pdf-a1b-ghostscript | txt | pass | 76 |  |
| pdf-a2b-verapdf-pass | png | pass | 147 |  |
| pptx-google-slides-export | pdf | pass | 147 | PDF/A not claimed |
| pptx-google-slides-export | png | pass | 190 |  |
| pptx-google-slides-export | key | skipped |  |  |
| pptx-powerpoint-charts-tables-groups | pdf | pass | 948 | PDF/A not claimed |
| pptx-powerpoint-charts-tables-groups | png | pass | 3283 |  |
| pptx-powerpoint-charts-tables-groups | odp | pass | 6271 |  |
| xls-biff8-real-world | xlsx | pass | 228 |  |
| xls-biff8-real-world | pdf | pass | 470 | PDF/A not claimed |
| xls-biff8-real-world | csv | pass | 52 |  |
| xls-biff8-real-world | ods | pass | 139 |  |
| xlsx-formulas-merges-charts | pdf | pass | 55 | PDF/A not claimed |
| xlsx-formulas-merges-charts | csv | pass | 38 |  |
| xlsx-formulas-merges-charts | ods | pass | 57 |  |
| xlsx-50000-merged-cells | pdf | pass | 862 | PDF/A not claimed |
| xlsx-50000-merged-cells | csv | pass | 719 |  |
| docx-images-in-tables | pdf | pass | 403 | PDF/A not claimed |
| docx-images-in-tables | odt | pass | 2260 |  |
| docx-images-in-tables | txt | pass | 145 |  |
| docx-images-in-tables | html | pass | 46 |  |
| docx-chartex | pdf | pass | 34 | PDF/A not claimed |
| docx-chartex | odt | pass | 1792 |  |
| docx-truncated-zip | pdf | pass | 111 |  |
| docx-truncated-zip | txt | pass | 163 |  |
| odt-text-document | pdf | pass | 173 | PDF/A not claimed |
| odt-text-document | docx | pass | 70 |  |
| odt-text-document | txt | pass | 36 |  |
| ods-table-with-title | xlsx | pass | 54 |  |
| ods-table-with-title | pdf | pass | 40 | PDF/A not claimed |
| ods-table-with-title | csv | pass | 38 |  |
| odp-presentation | pptx | pass | 1723 |  |
| odp-presentation | pdf | pass | 1875 | PDF/A not claimed |
| odp-presentation | png | pass | 1897 |  |
| keynote-2013-iwa | pdf | pass | 1412 | PDF/A not claimed |
| keynote-2013-iwa | pptx | pass | 1292 |  |
| keynote-2013-iwa | jpeg | pass | 1484 |  |
| keynote-2018-zipped-bundle | pdf | pass | 1520 | PDF/A not claimed |
| keynote-2018-zipped-bundle | pptx | pass | 1873 |  |
| pages-2013-iwa | pdf | pass | 1667 | PDF/A not claimed |
| pages-2013-iwa | docx | pass | 1555 |  |
| numbers-2013-iwa | pdf | pass | 1889 | PDF/A not claimed |
| numbers-2013-iwa | xlsx | pass | 1719 |  |
| numbers-2013-iwa | csv | pass | 1647 |  |
| zip-nested-office-docs | extract | pass | 38 |  |
| targz-zlib-source | extract | pass | 37 | no checker for . |
| 7z-umlaut-solid | extract | pass | 39 |  |
| 7z-encrypted | extract | pass | 31 |  |
| 7z-data-corrupted | extract | pass | 31 |  |
| rar3-unicode-names | extract | fail | 33 |  |
| rar5-encrypted | extract | pass | 34 |  |
| jpeg-cmyk-adobe | png | pass | 49 | SSIM 1.000 |
| jpeg-cmyk-adobe | pdf | pass | 42 | PDF/A not claimed |
| jpeg-cmyk-adobe | heic | pass | 72 | SSIM 0.996 |
| jpeg-cmyk-adobe | webp | pass | 115 | SSIM 0.990 |
| jpeg-cmyk-small | png | pass | 56 | SSIM 1.000 |
| png-16bit-hdr-room | tiff | pass | 35 | SSIM 1.000 |
| png-16bit-hdr-room | jpeg | pass | 37 | SSIM 0.993 |
| png-16bit-hdr-room | heic | pass | 159 | SSIM 0.995 |
| png-16bit-hdr-room | avif | fail |  |  |
| gif-animated-42-frames | webp | pass | 354 | SSIM 0.969 |
| gif-animated-42-frames | png | pass | 32 | SSIM 1.000 |
| gif-animated-42-frames | heic | pass | 46 | SSIM 0.969 |
| webp-animated-42-frames | gif | pass | 32 | SSIM 1.000 |
| webp-animated-42-frames | png | pass | 30 | SSIM 1.000 |
| avif-10bit-hdr-p3 | jpeg | pass | 489 | SSIM 0.997 |
| avif-10bit-hdr-p3 | png | pass | 3994 | SSIM 1.000 |
| avif-10bit-hdr-p3 | heic | pass | 571 | SSIM 0.999 |
| avif-10bit-hdr-p3 | tiff | pass | 478 | SSIM 1.000 |
| avif-sequence-animated | gif | pass | 211 |  |
| avif-sequence-animated | png | pass | 35 |  |
| tiff-multipage | pdf | pass | 34 | PDF/A not claimed |
| tiff-multipage | png | pass | 40 | SSIM 1.000 |
| tiff-multipage | jpeg | pass | 40 | SSIM 1.000 |
| tiff-ifd-loop | pdf | pass | 38 |  |
| tiff-ifd-loop | png | pass | 37 |  |
| svg-inkscape-filters | png | pass | 10491 | SSIM not measured |
| svg-inkscape-filters | pdf | pass | 12002 | PDF/A not claimed |
| svg-inkscape-filters | jpeg | pass | 6339 | SSIM not measured |
| svg-inkscape-i18n-text | png | pass | 190 | SSIM 0.997 |
| svg-inkscape-i18n-text | pdf | pass | 98 | PDF/A not claimed |
| psd-layer-effects | png | pass | 47 | SSIM 1.000 |
| psd-layer-effects | jpeg | pass | 32 | SSIM 0.998 |
| psd-layer-effects | tiff | pass | 34 | SSIM 1.000 |
| psd-layer-effects | pdf | pass | 34 | PDF/A not claimed |
| psd-cmyk-spot-channels | png | fail | 41 | SSIM 0.424 |
| psd-cmyk-spot-channels | jpeg | pass | 34 | SSIM 1.000 |
| psd-cmyk-spot-channels | tiff | pass | 135 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | jpeg | pass | 75382 | SSIM 0.998 |
| heic-samsung-200mp-gainmap | png | pass | 73389 | SSIM 1.000 |
| heic-samsung-200mp-gainmap | tiff | pass | 78621 | SSIM 1.000 |
| jpeg-exif-orientation-6 | png | pass | 308 | SSIM 1.000 |
| jpeg-exif-orientation-6 | heic | pass | 311 | SSIM 0.997 |
| jpeg-exif-orientation-6 | webp | pass | 489 | SSIM 0.996 |
| jpeg-exif-orientation-6 | pdf | pass | 214 | PDF/A not claimed |
| gif-decompression-bomb | png | pass | 52 |  |
| gif-decompression-bomb | jpeg | pass | 108 |  |
| gen-pdf-500-pages | png | pass | 71139 |  |
| gen-pdf-500-pages | jpeg | pass | 7124 |  |
| gen-pdf-password | png | pass | 171 |  |
| gen-pdf-password | txt | pass | 121 |  |
| gen-zip-truncated | extract | pass | 145 |  |
| gen-name-image | png | pass | 54 | SSIM 1.000 |
| gen-name-image | heic | pass | 59 | SSIM 0.996 |
| gen-name-image | webp | pass | 100 | SSIM 0.990 |
| gen-name-image | tiff | pass | 159 | SSIM 1.000 |
| gen-name-image | gif | pass | 41 | SSIM 0.999 |
| gen-name-image | bmp | pass | 27 | SSIM 1.000 |
| gen-name-image | pdf | pass | 114 | PDF/A not claimed |
| gen-name-video | mp4 | pass | 1175 | SSIM 1.000 |
| gen-name-video | mov | pass | 1214 | SSIM 1.000 |
| gen-name-video | webm | pass | 31618 | SSIM 0.980 |
| gen-name-video | avi | pass | 3971 | SSIM 0.949 |
| gen-name-video | wmv | pass | 5116 | SSIM 0.986 |
| gen-name-video | gif | pass | 15129 |  |
| gen-name-video | mp3 | pass | 569 |  |
| gen-name-video | m4a | pass | 1293 |  |
| gen-name-pdf | png | pass | 75339 |  |
| gen-name-pdf | jpeg | pass | 15975 |  |
| gen-name-pdf | docx | pass | 18218 |  |
| gen-name-pdf | txt | pass | 7639 |  |
| gen-name-pdf | markdown | pass | 7253 |  |
| gen-name-pdf | rtf | pass | 7308 |  |
| gen-name-pdf | html | pass | 16201 |  |
| gen-name-pdf | epub | pass | 17919 |  |
| gen-name-pdf | pptx | pass | 27006 |  |
| gen-name-pdf | xlsx | pass | 8829 |  |
| gen-name-audio | m4a | pass | 195 |  |
| gen-name-audio | wav | pass | 23 |  |
| gen-name-audio | aiff | pass | 70 |  |
| gen-name-audio | flac | pass | 31 |  |
| gen-name-audio | ogg | pass | 114 |  |
| gen-name-audio | opus | pass | 51 |  |
| gen-name-audio | wma | pass | 53 |  |
| gen-name-audio | alac | pass | 133 |  |
| gen-icloud-stub | png | pass |  |  |
