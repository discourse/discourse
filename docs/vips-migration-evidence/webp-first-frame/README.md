# WebP first-frame geometry evidence

All three renderer operations completed with matching 384 × 1 output dimensions and matching alpha. Visible RGB differs by at most 1 on the 0–255 scale. The two backends do not produce identical pixels or identical WebP bytes. On this small fixture, libvips has a higher warm median for every operation.

This supplement uses runtime source commit `a3c50521c64a57b149bb6c317449708ee06c0841`, which fixes first-frame WebP encoder selection. Source fingerprints and legacy instruction provenance are recorded in [manifest.json](manifest.json). The legacy instructions are replayed by [geometry_evidence.rb](geometry_evidence.rb); this is not an execution of the historical full Rails caller.

The run coordinator reports production image `discourse/base:2.0.20260812-0036`, digest `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`, with UID 1000. The JSON records Ruby 3.4.10, libvips 8.18.4, ImageMagick 7.1.2-27 Q16-HDRI, Linux 6.8.0-124-generic, and Landlock enabled. Image identity and UID are coordinator provenance; the result JSON does not independently record those fields.

## Before/after timing

“Before” means the ImageMagick renderer instructions; “after” means the libvips renderer at the source commit above. Each operation has 31 warm measurements per backend, following one initial validation per backend. Backend order alternates each iteration. Times are milliseconds, rounded to three decimals.

| Operation | Before median | Before p95 | After median | After p95 | After fresh-worker median | After fresh-worker p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [Downsize](downsize-results.json) | 39.843 | 49.208 | 41.426 | 46.969 | 403.547 | 426.633 |
| [Resize](resize-results.json) | 40.905 | 47.554 | 62.736 | 74.449 | 400.800 | 417.049 |
| [Crop](crop-results.json) | 41.644 | 50.029 | 65.175 | 72.416 | 464.799 | 515.869 |

Each fresh-worker column summarizes five successful libvips runs, each preceded by `DiscourseVips.before_fork`. There is no corresponding five-run fresh ImageMagick series. Fresh-worker p95 is the maximum of five observations and is not a stable tail-latency estimate. The harness uses the middle sorted observation for median and nearest-rank p95 (observation 30 of 31 for warm runs). These summaries were checked against the raw arrays.

The timed interval includes the renderer wrapper, IPC where applicable, sandbox child, priority 10, and encoding. It excludes Rails boot, source-quality probing, evidence decoding, complete caller work, and the FileHelper optimizer. Warm means the existing libvips worker can be reused; it does not mean the image is served from an image cache. The harness disables its local libvips operation cache and sets local concurrency to one. This small synthetic fixture does not establish production workload throughput or a general speedup.

## Fixture and encoder selection

[The 640-byte input](inputs/webp-quality-first-frame.webp) is an animated WebP with two lossy `VP8 ` frame payloads. Inspection of the first frame header confirms the horizontal scaling field is nonzero. The supplied fixture's first-frame ImageMagick quality estimate is 100; each result records that probe and the selection of quality 100 for libvips. The legacy command reads frame `[0]` and inherits its encoder selection without an explicit `-quality` option. Every retained comparison output contains `VP8L`, confirming intentional lossless WebP output from both renderers despite lossy input frames.

The harness uses ImageMagick's first-frame probe to select the libvips quality argument. It therefore demonstrates renderer behavior at quality 100, not independent execution of the corrected Rails caller's quality selection. The recorded warm-series source probes took 32.148 ms for downsize, 24.281 ms for resize, and 26.868 ms for crop; those are single observations outside transform timing, not a benchmark of the corrected probe.

## Output comparison

The linked images are one pixel high. Use the decoded PNG links or enlarge the strips for inspection; a normal-size preview cannot show their small differences.

| Operation | Before WebP / decoded PNG | After WebP / decoded PNG | Before / after bytes | Mean visible difference | Maximum visible difference | PSNR |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Downsize | [WebP](outputs/downsize/first-frame-lossless-output-imagemagick.webp) / [PNG](outputs/downsize/first-frame-lossless-output-imagemagick-decoded.png) | [WebP](outputs/downsize/first-frame-lossless-output-libvips.webp) / [PNG](outputs/downsize/first-frame-lossless-output-libvips-decoded.png) | 68 / 284 | 0.002604167 | 1 | 73.974 dB |
| Resize | [WebP](outputs/resize/first-frame-lossless-output-imagemagick.webp) / [PNG](outputs/resize/first-frame-lossless-output-imagemagick-decoded.png) | [WebP](outputs/resize/first-frame-lossless-output-libvips.webp) / [PNG](outputs/resize/first-frame-lossless-output-libvips-decoded.png) | 72 / 72 | 0.003472222 | 1 | 72.725 dB |
| Crop | [WebP](outputs/crop/first-frame-lossless-output-imagemagick.webp) / [PNG](outputs/crop/first-frame-lossless-output-imagemagick-decoded.png) | [WebP](outputs/crop/first-frame-lossless-output-libvips.webp) / [PNG](outputs/crop/first-frame-lossless-output-libvips-decoded.png) | 72 / 72 | 0.003472222 | 1 | 72.725 dB |

Every initial validation succeeded. Both backends match the expected dimensions for every operation; all three cases are eligible for paired timing and all failure lists are empty. The pixel metrics compare ImageMagick-decoded PNGs in 8-bit sRGB, flattened onto black and white separately. Both backgrounds produce the values shown above. Alpha mean and maximum differences are zero. Hidden RGB beneath transparent pixels is excluded. This does not establish equality in another color space, original metadata, or byte encoding.

Downsize retains metadata on the libvips path: its output reports TopLeft orientation and EXIF, with 180 EXIF bytes in the decoded evidence, versus Undefined orientation and no EXIF for ImageMagick. This accounts for a material output difference that pixel metrics alone omit. Resize and crop request metadata stripping; both backends report no EXIF, no decoded ICC profile, and Undefined orientation. All decoded outputs are `uchar`; no decoded output has an ICC profile.

The retained WebP SHA-256 values are:

| Operation | Backend | SHA-256 |
| --- | --- | --- |
| Downsize | ImageMagick | `e22f87afa498be2a2d26eaf96c3120d2520dfd3d0d5eb4a1407e6f2b7bce9662` |
| Downsize | libvips | `26400c24c4da7bb7bb4ca432a3136dfa53c7cd11dd7836dee1059d2ef2bd7fc7` |
| Resize | ImageMagick | `441458e16263ef4e4b100ab0b86ed246bc1d15d2d03ef3e767de2b668728647a` |
| Resize | libvips | `2adae1295bc369a08580f87aed0a2ba299a6618237f2315b1d6e100a142064d8` |
| Crop | ImageMagick | `441458e16263ef4e4b100ab0b86ed246bc1d15d2d03ef3e767de2b668728647a` |
| Crop | libvips | `2adae1295bc369a08580f87aed0a2ba299a6618237f2315b1d6e100a142064d8` |

All five fresh-worker outputs per operation have the same hash as that operation's retained libvips output. The 31 warm outputs overwrite the same path; only the final output is fingerprinted, so byte stability across all warm iterations is not proven.

## Artifact audit and remaining scope

A host-side audit with Python's standard library verified 36 unique recorded file hashes: 12 source/reference/profile files, one input, the manifest, the harness, six comparison WebPs, and 15 fresh-worker WebPs. It also checked raw timing counts and summaries, fresh-worker success, and WebP chunk types without rerunning the benchmark. The manifest hash is `0fb5ce8a27101faa97c5e02eb27cb98b0b2492fe98dbd49c02d6f120ddfc7073`; the harness hash is `6721efa4f681535ba12b07a7723feb5649b9ddd2832685404faf33cc154fd55d`. Decoded PNG hashes are not recorded, so the numerical pixel comparison remains the recorded harness result rather than an independently repeated pixel test.

The evidence covers one synthetic input and three renderer operations. Complete Rails caller behavior, the corrected quality probe's own cost, post-optimizer output, a broader image corpus, and representative production load require separate evidence. This audit did not rerun runtime tests or independently verify the coordinator's container image and UID.

## Reproduction

With this directory at `/root/discourse-vips-migration-01a0846e/webp-geometry-review` and its locked gems installed in the session gem volume, run the following on the supplied Linux benchmark host. Run each operation sequentially, changing `OPERATION` to `downsize`, `resize`, then `crop`; preserve the original results before rerunning because the harness overwrites outputs.

```bash
docker run --rm --user discourse --cpus 2 --memory 2g --memory-swap 3g \
  -v /root/discourse-vips-migration-01a0846e/webp-geometry-review:/bench \
  -v /root/discourse-vips-migration-01a0846e/animation/gems:/gems \
  -w /bench -e BUNDLE_PATH=/gems -e OPERATION=downsize \
  discourse/base:2.0.20260812-0036 \
  bundle exec ruby -r ./boot.rb geometry_evidence.rb
```
