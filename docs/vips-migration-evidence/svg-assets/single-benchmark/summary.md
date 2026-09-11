| Input | PNG dimensions before → after | PNG bytes before → after | ImageMagick median ms | libvips median ms | ImageMagick extra MiB | libvips extra MiB |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `drop-shadow.svg` | 240×100 → 240×100 | 1286 → 1733 | 40.38 | 71.54 | 4.172 | 6.422 |
| `large.svg` | 3000×1000 → 300×100 | 43067 → 1469 | 1175.38 | 64.43 | 95.590 | 5.668 |
| `fixed.svg` | 120×80 → 120×80 | 306 → 467 | 30.04 | 66.83 | 3.379 | 5.293 |
| `gradient-logo.svg` | 240×100 → 240×100 | 7131 → 4018 | 326.90 | 393.11 | 5.020 | 7.266 |
| `image.svg` | 100×50 → 100×50 | 304 → 399 | 305.19 | 386.54 | 4.762 | 8.469 |
| `leading-whitespace-viewbox.svg` | 120×90 → Error | 308 → Error | 33.59 | 52.01 | 3.383 | 5.691 |
| `tiny.svg` | 115×86 → 115×86 | 1439 → 1081 | 44.46 | 65.75 | 3.598 | 6.312 |
| `transparency.svg` | 12×4 → 12×4 | 329 → 294 | 31.53 | 43.52 | 3.090 | 5.680 |
| `viewbox.svg` | 120×90 → 120×90 | 308 → 488 | 36.94 | 43.15 | 3.383 | 6.062 |
| `zero-height.svg` | 80×90 → Error | 304 → Error | 33.78 | 29.28 | 3.141 | 5.164 |
| `zero-width.svg` | 120×60 → Error | 305 → Error | 32.70 | 27.80 | 3.137 | 6.426 |
| `zero_sized.svg` | 120×90 → Error | 1171 → Error | 32.79 | 29.06 | 3.445 | 5.699 |
| `physical-units.svg` | 192×96 → 192×96 | 2281 → 1345 | 36.18 | 41.65 | 3.980 | 6.535 |
| `css-dimensions.svg` | Error → 120×80 | Error → 498 | 28.55 | 35.93 | 2.863 | 6.043 |
| `malformed.svg` | Error → Error | Error → Error | 33.42 | 35.04 | 2.848 | 4.934 |
