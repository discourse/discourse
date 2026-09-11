| Input | PNG dimensions before → after | PNG bytes before → after | ImageMagick median ms | libvips median ms | ImageMagick extra MiB | libvips extra MiB |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `drop-shadow.svg` | 240×100 → 240×100 | 1286 → 1733 | 40.21 | 46.30 | 4.172 | 6.414 |
| `large.svg` | 3000×1000 → 300×100 | 43067 → 1469 | 1246.01 | 39.86 | 95.523 | 5.660 |
| `fixed.svg` | 120×80 → 120×80 | 306 → 467 | 37.90 | 34.24 | 3.379 | 5.184 |
| `gradient-logo.svg` | 240×100 → 240×100 | 7131 → 4018 | 346.72 | 330.10 | 5.004 | 7.062 |
| `image.svg` | 100×50 → 100×50 | 304 → 399 | 345.19 | 316.76 | 4.719 | 8.355 |
| `leading-whitespace-viewbox.svg` | 120×90 → Error | 308 → Error | 37.33 | 28.88 | 3.383 | 5.672 |
| `tiny.svg` | 115×86 → 115×86 | 1439 → 1081 | 44.19 | 35.61 | 3.445 | 6.383 |
| `transparency.svg` | 12×4 → 12×4 | 329 → 294 | 38.22 | 36.32 | 3.090 | 5.641 |
| `viewbox.svg` | 120×90 → 120×90 | 308 → 488 | 42.97 | 38.53 | 3.383 | 6.137 |
| `zero-height.svg` | 80×90 → Error | 304 → Error | 38.48 | 28.25 | 3.141 | 5.391 |
| `zero-width.svg` | 120×60 → Error | 305 → Error | 39.04 | 29.53 | 3.141 | 6.422 |
| `zero_sized.svg` | 120×90 → Error | 1171 → Error | 40.09 | 28.63 | 3.441 | 5.676 |
| `physical-units.svg` | 192×96 → 192×96 | 2281 → 1345 | 47.25 | 35.29 | 3.977 | 6.609 |
| `css-dimensions.svg` | Error → 120×80 | Error → 498 | 36.97 | 34.55 | 2.840 | 6.137 |
| `malformed.svg` | Error → Error | Error → Error | 36.82 | 28.66 | 2.840 | 4.961 |
