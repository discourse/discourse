# Quality query benchmark

This bundle compares the actual `ImageMagick.image_quality` helper with the actual `DiscourseVips.image_quality` facade and sandbox. The runtime is frozen at `28582e86c45dd1c791b01fc876382fbb8e444f07`. It has no benchmark runtime results yet.

## Freeze and dependencies

Run locally after the source commit is ready:

```sh
python3 /tmp/discourse-vips-callers-01a0846e/public/discourse-task/quality-benchmark/build_bundle.py \
  --source /tmp/discourse-vips-migration-01a0846e \
  --commit 28582e86c45dd1c791b01fc876382fbb8e444f07 \
  --locked-runtime /tmp/discourse-vips-evidence-01a0846e/public/discourse-task/geometry-benchmark
```

The builder requires HEAD to equal the supplied commit and every copied runtime file to match its committed bytes. It copies the estimator's LICENSE and NOTICE, eleven runtime files, twenty-three copied inputs, the original matrix recipe, the WebP inheritance recipe and its manifest/static fragments, and the existing geometry benchmark's locked Gemfile. It records content SHA-256 hashes and refuses to overwrite an existing source manifest. It does not copy gems, `.bundle`, caches, or previous output.

Use the existing production benchmark installation pattern with this Gemfile and lockfile. It pins ruby-vips 2.3.0, Landlock 0.5.1, Nokogiri 1.19.4 and Racc 1.8.1 with their existing dependencies. There is no Rails boot. The image is `discourse/base:2.0.20260812-0036`, digest `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`; this is a benchmark image, not a verified deployment override. The coordinator retains the existing two-CPU, two-GiB execution limits and runs the following commands serially inside the mounted bundle:

```sh
MODE=prepare bundle exec ruby boot.rb
MODE=benchmark bundle exec ruby boot.rb
MODE=matrix bundle exec ruby boot.rb
```

`RESULT_PATH` can select a new result filename for benchmark or matrix mode. Existing result files and generated directories are preserved; use a separate bundle for a new source snapshot. Save the coordinator's exact container command, runtime installation log and console output alongside the results.

## Representative measurements

Four additional animations cover first-frame quality inheritance: first-100-then-ordinary (100100), ordinary-then-100 (92100), later-100-not-sticky (9210092), and ordinary-control (9292). Their recipe, manifest, animation bytes and static fragments are retained under `reference/`. The generator changes a VP8 scaling field without changing decoded dimensions or pixels; these cases exercise ImageMagick's fragment-byte classification and inheritance, not actual lossless encoding. The copied manifest records the coordinator's earlier decoder checks; the benchmark independently compares both public query values and these expected integers.

The nineteen copied inputs include a natural JPEG photo, grayscale and progressive JPEGs, a tiny matrix source and logo; PNG and SVG; static and animated GIF; static, animated, lossless-static and lossless-animated WebP; static and multipage AVIF; single-entry and multi-entry ICO; and JXL. Preparation adds three tiny JPEGs: one without a quality override, one with a single valid nonzero quantization coefficient changed, and one saved through ruby-vips at Q75. The exact generation recipe, custom-table byte offset, original byte, replacement byte and file hashes go into `corpus.json`.

Each of the 26 samples receives one validation call per backend. A failed or unequal pair remains an explicit result and receives no repeated timing calls. The JXL fixture is an expected unsupported case: the pinned ImageMagick build lacks a JXL delegate, and the native quality operation intentionally rejects it. Only the specific missing-delegate and unsupported-format errors qualify as this expected result; other errors remain failures. Matching successful pairs receive 31 iterations in alternating backend order. Every timed result retains its actual return value; a later error or value change stops that sample and excludes its timing summary. Five additional photo queries start a fresh libvips worker each time, including worker startup and IPC within the clock. Worker reset occurs outside the clock, and filesystem caches remain warm.

Timing includes the public query, instrumentation wrapper, process or worker communication, and sandbox. It excludes dependency installation, Rails boot, fixture generation, source format discovery and FileHelper optimization. Input formats are recorded before timing. The native query's return value is compared to the helper's observed value, not to the nominal encoder quality.

The legacy helper queries the entire file without a `[0]` suffix and converts the resulting text to an integer. Animated and multipage files can therefore return concatenated quality values, outside 1–100. The harness preserves this behavior and records those integers without clamping or silently choosing one frame. JXL remains an explicit unsupported case. HEIC/HEIF are outside this query corpus because upload ingress converts them to JPEG before this quality query; AVIF is included.

## Bounded compatibility matrix

`matrix.rb` follows `reference/check_jpeg_quality.rb`: Q1–100 for each of color/grayscale and baseline/progressive ImageMagick JPEGs, followed by Q1–100 through ruby-vips `jpegsave` on the pinned image's JPEG encoder. That is exactly 500 generated files and 500 comparisons. The source is the existing tiny `exif_orientation.jpg` fixture. This matrix is untimed compatibility evidence; it does not perform 31 repeats per file or create large decoded Ruby arrays.

Every comparison calls both public helpers, including the native worker and sandbox. Generation failures, query failures and mismatches remain individual records. Files, hashes, generation settings and reported quality values are retained. Requested Q is recorded as an encoder input, not asserted to equal ImageMagick's estimate; this distinction matters for the production JPEG encoder's quantization tables.

## Artifacts and acceptance

Retain `source-manifest.json`, the locked dependencies, runtime source and attribution files, `reference/`, `inputs/`, all harness scripts, `corpus.json`, `generated/`, `quality-results.json`, `matrix-results.json`, and `matrix/`. Reports include source hashes, harness hashes, image identity, actual library versions, raw timings, actual query values and input-preservation checks.

Both measured modes exit nonzero for any unresolved mismatch or failure. Inspect individual records before reporting compatibility or timing results. A matching matrix does not establish behavior for every custom JPEG table or malformed input, and these measurements do not establish caller-level optimizer performance, deployment configuration or CI status.
