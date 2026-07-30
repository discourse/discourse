# Stock vips production-path benchmark

This benchmark compares the final high-risk production paths selected by
`use_vips_for_image_processing` with their existing ImageMagick paths. It runs
inside the updated Discourse runtime image and invokes the real
`OptimizedImage`, `UploadCreator`, `Upload`, `Vips`, and `ImageMagick`
implementations.

The definitive migration run is summarized in [report.md](report.md). Its
checksummed raw evidence and representative outputs are preserved in
`results/vips-image-processing-benchmark-664bd02c.tar.gz`.

The corpus and operations cover:

- optimized resize of a photographic JPEG;
- north-gravity crop of a high-detail upload;
- shrink-only downsize of an 8900×8900 JPEG;
- qualifying uncompressed transparent PNG conversion through the production
  eligibility, target-quality, keep/discard, and replacement path;
- JPEG recompression through the production source-quality, target-quality,
  keep/discard, and replacement path;
- HEIC conversion through the production upload path;
- EXIF orientation correction;
- SVG dimensions;
- the animated-WebP fallback probe;
- source JPEG quality;
- ICO conversion.

Each candidate receives three warmups by default. The harness then collects 15
dedicated timing samples and five dedicated process-tree RSS samples per
operation and candidate in randomized order. It reports timing p50 and the
maximum observed RSS peak; it never averages per-run RSS peaks.

Every recorded sample is compared with the preserved ImageMagick reference
before it is written to `samples.jsonl`. Raster comparisons require exact
dimensions and encoded format, the declared normalized mean RGBA error
threshold including alpha, the declared encoded-size bound, and any applicable
orientation and metadata-stripping requirement. EXIF, XMP, IPTC, and
ICC-profile presence must match ImageMagick for every raster result. XMP
contents, IPTC contents, JPEG comments, and user-meaningful EXIF camera,
capture-time, and GPS fields must also match. Opaque MakerNote blobs and
structural EXIF fields are recorded but are not equality requirements because
libvips reconstructs those records when it encodes a new image. Scalar probes
require exact equality.

The optimized resize and north crop derive their target quality with the same
`Upload#target_image_quality` policy used by `OptimizedImage.create_for`.
Shrink-only downsize preserves the production caller's lack of an explicit
quality override. The parent initializes both production `ImageOptim`
configurations before forking so randomized warmups do not depend on
process-local binary discovery.

The process-tree RSS measurement includes the forked Rails operation process
and every descendant. This captures both in-process work and CLI children while
excluding the already-loaded parent driver. Both candidates inherit their
library defaults. The harness rejects any environment containing
`VIPS_CONCURRENCY`. A separate no-operation fork baseline makes the large shared
Rails process footprint visible and prevents small RSS differences from being
over-interpreted. Every operation is released only after the RSS monitor
completes its first process-tree scan.

Run the benchmark as the unprivileged `discourse` user with the updated runtime
image, a prepared Rails test database, and these required environment values:

```text
RAILS_ENV=test \
VIPS_BENCH_RESULTS_DIR=/benchmark-results \
BENCHMARK_SOURCE_REVISION=<core-production-revision> \
BENCHMARK_DOCKER_REVISION=<discourse-docker-revision> \
BENCHMARK_RUNTIME_IMAGE_ID=<updated-runtime-image-id> \
BENCHMARK_IMAGE_ID=<benchmark-wrapper-image-id> \
bin/rails runner script/benchmarks/vips_image_processing/benchmark.rb
```

The source revision identifies the production implementation being measured.
The harness verifies that it equals the checkout's full `git rev-parse HEAD` and
refuses a dirty source worktree. The Docker revision must also be a full Git
revision. Mount the checkout's Git worktree metadata read-only into the
benchmark container so these checks are independent of environment labels. The
harness itself, every production source file it invokes, policy and profile
data, the lockfile, binaries, and installed package versions are recorded or
hashed in `environment.json`.

The result directory contains:

- `environment.json` with source, image, dependency, host, setting, and fixture
  evidence;
- `correctness.json` and representative input/output artifacts;
- `samples.jsonl` with every qualified raw timing and RSS sample;
- `analysis.json` and `summary.md`;
- `rss-baseline.json`;
- `artifacts.sha256`;
- `run-state.json`.

This benchmark is sequential. It makes no concurrent-throughput claim. If
throughput is evaluated later, use independent driver processes and report
batch makespan or images per second.
