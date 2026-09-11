| Input | PNG dimensions, before → after | PNG bytes, before → after | ImageMagick median ms | libvips median ms | ImageMagick extra MiB | libvips extra MiB |
|---|---|---:|---:|---:|---:|---:|
| drop-shadow.svg | 240×100 → 240×100 | 1286 → 1733 | 41.86 | 41.72 | 4.176 | 6.391 |
| large.svg | 3000×1000 → 300×100 | 43067 → 1469 | 1263.70 | 39.28 | 95.520 | 5.645 |
| fixed.svg | 120×80 → 120×80 | 306 → 467 | 33.25 | 35.89 | 3.383 | 5.168 |
| gradient-logo.svg | 240×100 → 240×100 | 7131 → 4018 | 342.47 | 307.55 | 5.094 | 7.066 |
| image.svg | 100×50 → 100×50 | 304 → 399 | 315.82 | 308.51 | 4.715 | 8.328 |
| leading-whitespace-viewbox.svg | 120×90 → error | 308 → — | 34.86 | 29.65 | 3.383 | 5.664 |
| tiny.svg | 115×86 → 115×86 | 1439 → 1081 | 41.79 | 39.39 | 3.539 | 6.379 |
| transparency.svg | 12×4 → 12×4 | 329 → 294 | 33.78 | 38.61 | 3.090 | 5.645 |
| viewbox.svg | 120×90 → 120×90 | 308 → 488 | 37.52 | 38.44 | 3.383 | 6.129 |
| zero-height.svg | 80×90 → error | 304 → — | 32.53 | 31.25 | 3.141 | 5.395 |
| zero-width.svg | 120×60 → error | 305 → — | 31.08 | 33.45 | 3.137 | 6.430 |
| zero_sized.svg | 120×90 → error | 1171 → — | 31.56 | 35.15 | 3.445 | 5.672 |
| physical-units.svg | 192×96 → 192×96 | 2281 → 1345 | 40.10 | 42.20 | 3.977 | 6.430 |
| css-dimensions.svg | error → 120×80 | — → 498 | 30.84 | 39.02 | 2.840 | 6.137 |
| malformed.svg | error → error | — → — | 37.75 | 29.85 | 2.840 | 4.934 |
