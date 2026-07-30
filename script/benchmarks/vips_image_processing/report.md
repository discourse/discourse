# Stock vips production-path benchmark report

## Result

The vips-enabled production paths were faster in 9 of 11 operations. No time
regression met the material-regression threshold of both 5 ms and 10%.
Optimized north crop was 7.0% slower and the SVG dimension probe was 5.3%
slower. Every measured output passed its operation-specific semantic and visual
comparison with the preserved ImageMagick reference.

| Operation | Method | p50 time | Maximum peak RSS | Time difference vs IM | Memory difference vs IM |
| --- | --- | ---: | ---: | ---: | ---: |
| Optimized resize (photograph) | ImageMagick | 263.58 ms | 727.67 MiB | — | — |
| Optimized resize (photograph) | Vips | 146.64 ms | 681.50 MiB | -116.94 ms (-44.4%) | -46.17 MiB (-6.3%) |
| Optimized north crop (high detail) | ImageMagick | 794.61 ms | 450.71 MiB | — | — |
| Optimized north crop (high detail) | Vips | 850.54 ms | 724.41 MiB | +55.92 ms (+7.0%) | +273.70 MiB (+60.7%) |
| Optimized downsize (8900×8900) | ImageMagick | 953.86 ms | 1477.15 MiB | — | — |
| Optimized downsize (8900×8900) | Vips | 492.88 ms | 426.34 MiB | -460.98 ms (-48.3%) | -1050.80 MiB (-71.1%) |
| PNG-to-JPEG conversion | ImageMagick | 199.03 ms | 686.93 MiB | — | — |
| PNG-to-JPEG conversion | Vips | 44.37 ms | 727.76 MiB | -154.67 ms (-77.7%) | +40.83 MiB (+5.9%) |
| JPEG recompression | ImageMagick | 194.60 ms | 448.19 MiB | — | — |
| JPEG recompression | Vips | 38.44 ms | 727.78 MiB | -156.15 ms (-80.2%) | +279.59 MiB (+62.4%) |
| HEIC-to-JPEG conversion | ImageMagick | 54.67 ms | 727.70 MiB | — | — |
| HEIC-to-JPEG conversion | Vips | 43.05 ms | 396.38 MiB | -11.62 ms (-21.3%) | -331.32 MiB (-45.5%) |
| EXIF orientation correction | ImageMagick | 61.98 ms | 727.83 MiB | — | — |
| EXIF orientation correction | Vips | 39.21 ms | 727.81 MiB | -22.78 ms (-36.7%) | -0.02 MiB (-0.0%) |
| SVG dimension probe | ImageMagick | 120.22 ms | 375.59 MiB | — | — |
| SVG dimension probe | Vips | 126.59 ms | 720.98 MiB | +6.38 ms (+5.3%) | +345.39 MiB (+92.0%) |
| Animated WebP fallback probe | ImageMagick | 116.14 ms | 690.62 MiB | — | — |
| Animated WebP fallback probe | Vips | 113.40 ms | 724.61 MiB | -2.74 ms (-2.4%) | +33.98 MiB (+4.9%) |
| JPEG target-quality decision | ImageMagick | 111.30 ms | 379.65 MiB | — | — |
| JPEG target-quality decision | Vips | 0.43 ms | 345.21 MiB | -110.88 ms (-99.6%) | -34.44 MiB (-9.1%) |
| ICO-to-PNG conversion | ImageMagick | 13.60 ms | 690.63 MiB | — | — |
| ICO-to-PNG conversion | Vips | 3.78 ms | 372.95 MiB | -9.81 ms (-72.2%) | -317.68 MiB (-46.0%) |

## Method

The benchmark ran the final production implementations in the updated
Discourse Docker image. Each of the 22 operation and processor cells received
three warmups, 15 dedicated timing samples, and five dedicated RSS samples in
randomized order. Both processors used their defaults; `VIPS_CONCURRENCY` was
absent.

Timing covers the production operation but excludes fixture preparation and
post-run validation. RSS is the maximum observed sum of `VmRSS` for the forked
Rails operation process and all descendants. It is not a mean of per-run peaks.
The no-operation fork baseline was 290.01 MiB p50 and 290.04 MiB maximum.

The completed run contains 330 timing samples and 110 RSS samples. All 440
samples qualified before being recorded, every RSS value was nonzero, and every
one of the 22 cells contains the expected 15 timing and five RSS samples.

## Correctness

Raster comparisons require identical dimensions and encoded format, declared
alpha-aware normalized mean RGBA error and encoded-size bounds, and applicable
orientation and metadata behavior. Scalar probes require exact equality.

The PNG-to-JPEG fixture includes legacy raw-profile XMP and IPTC plus EXIF, ICC,
and a comment. Both processors preserved the same XMP and IPTC content digests,
the same comment, and the same metadata presence. Semantic camera, capture-time,
and GPS EXIF fields are compared where present. Opaque MakerNote blobs are
recorded but are not byte-equality requirements because libvips reconstructs
EXIF records during encoding.

## Regression investigation

Optimized north crop uses a stock-vips cover resize followed by a north-gravity
crop. Its 55.92 ms time increase is 7.0%, below the declared 10% material
threshold. The output has the required 640×640 geometry, a 0.00494 normalized
mean RGBA error, and a 0.986 encoded-size ratio against ImageMagick.

The SVG dimension probe was 6.38 ms, or 5.3%, slower. Short SafeExec commands
show approximately 100 ms timing bands because the Landlock process wrapper
polls child completion at 100 ms intervals. The small SVG difference is inside
that launcher-resolution effect.

Peak process-tree RSS is intentionally conservative. It sums RSS for concurrent
SafeExec launcher and CLI descendants, so shared copy-on-write pages can be
counted once per process. The five raw RSS samples show corresponding bands
depending on whether a scan catches an overlapping launcher. Consequently the
table is the requested maximum process-tree measurement, not a direct estimate
of either engine's private heap. The most substantial transform remains
unambiguous: the 8900×8900 downsize reduced maximum peak RSS by 1050.80 MiB
(71.1%) with vips.

## Provenance and raw evidence

- Core source revision:
  `664bd02c591b23b7bac43ebcfe36def8be43e373`
- Docker source revision:
  `831e67e22f2b613d0b126e8edc04ac55ca87a822`
- Runtime image:
  `sha256:2bed34f444123e0e2b951f2e4dc4584f43c1cd6265aca02f94e6c2cc50ea4916`
- Benchmark wrapper image:
  `sha256:6164af63521c9be7e782ecf9722f5cfcca41705c925251f08a9588f48ec3d910`
- Random seed: `20260730`
- Evidence archive:
  `results/vips-image-processing-benchmark-664bd02c.tar.gz`
- Archive SHA-256:
  `25d6cd485537c1926f73b215eacb557050e05ce4fa5ad608cfac450e9af9309b`

The archive contains the environment and source hashes, fixture hashes, all raw
samples, machine-readable analysis, correctness records, representative inputs
and generated outputs, the no-operation RSS baseline, the run-state ledger, and
checksums for every included artifact.
