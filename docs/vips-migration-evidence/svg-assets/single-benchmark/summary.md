| Input | PNG dimensions, before → after | PNG bytes, before → after | ImageMagick median ms | libvips median ms | ImageMagick extra MiB | libvips extra MiB |
|---|---|---:|---:|---:|---:|---:|
| large.svg | 3000×1000 → 300×100 | 43067 → 1469 | 1253.95 | 34.61 | 95.535 | 5.918 |
| fixed.svg | 120×80 → 120×80 | 306 → 467 | 38.26 | 32.32 | 3.379 | 5.180 |
| gradient-logo.svg | 240×100 → 240×100 | 7131 → 4018 | 354.18 | 305.98 | 5.074 | 7.355 |
| image.svg | 100×50 → 100×50 | 304 → 399 | 348.13 | 292.99 | 4.727 | 6.512 |
| leading-whitespace-viewbox.svg | 120×90 → error | 308 → — | 33.75 | 24.96 | 3.383 | 6.168 |
| tiny.svg | 115×86 → 115×86 | 1439 → 1081 | 36.55 | 36.79 | 3.531 | 6.156 |
| transparency.svg | 12×4 → 12×4 | 329 → 294 | 29.78 | 33.06 | 3.086 | 5.754 |
| viewbox.svg | 120×90 → 120×90 | 308 → 488 | 31.38 | 35.12 | 3.383 | 5.926 |
| zero-height.svg | 80×90 → error | 304 → — | 31.44 | 26.49 | 3.137 | 5.168 |
| zero-width.svg | 120×60 → error | 305 → — | 32.44 | 24.96 | 3.137 | 5.168 |
| zero_sized.svg | 120×90 → error | 1171 → — | 34.19 | 28.83 | 3.441 | 6.141 |
| physical-units.svg | 192×96 → 192×96 | 2281 → 1345 | 41.92 | 41.82 | 3.977 | 6.641 |
| css-dimensions.svg | error → 120×80 | — → 498 | 33.08 | 33.12 | 2.840 | 6.137 |
| malformed.svg | error → error | — → — | 32.05 | 26.62 | 2.840 | 4.738 |
