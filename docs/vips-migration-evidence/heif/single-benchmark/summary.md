| Input | Dimensions, before → after | JPEG bytes, before → after | ImageMagick median ms | libvips median ms | ImageMagick extra MiB | libvips extra MiB |
|---|---|---:|---:|---:|---:|---:|
| heif-color-grid-12bit.heic | 60×40 → 60×40 | 888 → 818 | 32.86 | 31.56 | 2.848 | 4.715 |
| heif-color-grid-8bit.heic | 60×40 → 60×40 | 880 → 815 | 32.25 | 31.16 | 2.844 | 4.496 |
| heif-color-grid-alpha-12bit.heic | 60×40 → 60×40 | 870 → 816 | 33.72 | 32.09 | 3.082 | 4.742 |
| heif-color-grid-alpha-8bit.heic | 60×40 → 60×40 | 870 → 814 | 32.02 | 33.67 | 3.074 | 4.723 |
| heif-color-grid-mirrored.heic | 60×40 → 60×40 | 879 → 815 | 33.73 | 40.40 | 2.945 | 5.980 |
| heif-color-grid-rotated.heic | 40×60 → 40×60 | 927 → 850 | 37.68 | 41.30 | 2.914 | 5.492 |
| should_be_jpeg.heic | 846×1129 → 846×1129 | 250814 → 235175 | 198.02 | 148.18 | 30.840 | 13.301 |
| heif-truncated-payload.heic | error → error | — → — | 32.62 | 25.66 | 2.840 | 4.480 |
