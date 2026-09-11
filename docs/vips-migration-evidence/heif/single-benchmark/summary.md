| Input | JPEG dimensions before → after | JPEG bytes before → after | ImageMagick median ms | libvips median ms | ImageMagick extra MiB | libvips extra MiB |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `heif-color-grid-12bit.heic` | 60×40 → 60×40 | 888 → 818 | 30.59 | 33.05 | 2.844 | 4.496 |
| `heif-color-grid-8bit.heic` | 60×40 → 60×40 | 880 → 815 | 33.86 | 34.76 | 3.082 | 4.461 |
| `heif-color-grid-alpha-12bit.heic` | 60×40 → 60×40 | 870 → 816 | 35.30 | 34.95 | 3.078 | 4.711 |
| `heif-color-grid-alpha-8bit.heic` | 60×40 → 60×40 | 870 → 814 | 41.63 | 35.40 | 2.852 | 4.703 |
| `heif-color-grid-mirrored.heic` | 60×40 → 60×40 | 879 → 815 | 33.64 | 40.63 | 2.844 | 5.988 |
| `heif-color-grid-rotated.heic` | 40×60 → 40×60 | 927 → 850 | 36.60 | 42.21 | 2.840 | 5.453 |
| `should_be_jpeg.heic` | 846×1129 → 846×1129 | 250814 → 235175 | 224.32 | 140.06 | 30.836 | 13.375 |
| `heif-truncated-payload.heic` | Error → Error | Error → Error | 32.70 | 27.61 | 2.840 | 4.484 |
