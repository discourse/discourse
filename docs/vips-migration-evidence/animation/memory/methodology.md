[Summary](summary.md), [raw trials](raw.jsonl), [source and image manifest](measurement-manifest.json), and [PR source correspondence](pr-source-correspondence.json).

Memory is the median of three fresh-container `memory.peak` readings, converted from bytes to MiB (1 MiB = 1,048,576 bytes). Each container boots a minimal Ruby harness, performs one warm-up and five animation-probe calls using a single backend, then reads the cgroup's lifetime peak. The total includes the harness, persistent libvips worker, operation subprocesses, and memory charged for kernel structures and file cache. It is not process RSS or memory added above an idle baseline. Host filesystem caches are not cleared. Both backends load the same harness dependencies; only the libvips backend starts its worker.

Every run uses UID/GID 1000, two CPUs, 2 GiB memory and 3 GiB combined memory/swap, in `discourse/base:2.0.20260812-0036`, digest `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`. Runs are serialized under an exclusive collection lock; backend order alternates by replicate. Source bundles are mounted read-only, and temporary output and worker state are isolated to the container.

Bundler uses frozen mode with the Gemfile and lockfile included here. This verified lockfile was copied from the SVG-dimensions benchmark to avoid incomplete checksum entries in other historical bundles. Its shared dependency versions match the animation bundle. It also declares Nokogiri and racc, but the animation harness does not load them. The original animation source and dependency lockfile remain unchanged and are hashed separately in `measurement-manifest.json`.

All seven existing animation-probe samples are measured. Warm runtime medians come from a separate series of 31 calls per backend; memory and runtime were not sampled together. Both comparisons invoke the ImageMagick and libvips fallback operations directly, excluding FastImage and Rails boot from runtime timing. The memory total includes the minimal harness boot. These measurements do not describe the ordinary FastImage-first upload path or a full Rails process.

`pr-source-correspondence.json` compares the measured source with PR43453 at `dfbd095f54e7d0b0c32204d6768880cbbedd2fdc`. The worker, IPC, sandbox, ImageMagick wrapper, and instrumentation are byte-identical. The facade differs only in its supported-format comment; executable lines match.

## Reproduction

The immutable [original animation benchmark bundle](https://github.com/discourse/discourse/tree/860ea0809f59ba11440e2e6b375f8be487826ac4/docs/vips-migration-evidence/animation/benchmark) contains the source, all seven fixtures, and the original timing harness. Obtain that exact directory from the pinned commit, together with the files in this memory directory.

The recorded collector uses this explicit host layout:

- `/root/discourse-vips-migration-01a0846e/animation/`: contents of the original benchmark directory.
- `/root/discourse-vips-migration-01a0846e/animation/gems/`: installed gems for the included memory Gemfile/lockfile, using `BUNDLE_PATH=/gems` inside the production image.
- `/root/discourse-vips-migration-01a0846e/memory-benchmarks/animation-final/`: contents of this memory directory.

Create the gem directory writable by UID/GID 1000. Install dependencies with the pinned production image, mounting the gem directory at `/gems` and this memory directory at `/probe`, and running `bundle install` with `BUNDLE_GEMFILE=/probe/Gemfile`, `BUNDLE_PATH=/gems`, and `BUNDLE_FROZEN=true`. The collector verifies the image digest before measuring.

Preserve the published raw results elsewhere before a fresh reproduction. Run:

```sh
python3 /root/discourse-vips-migration-01a0846e/memory-benchmarks/animation-final/collect.py
python3 /root/discourse-vips-migration-01a0846e/memory-benchmarks/animation-final/summarize.py
```

`collect.py` writes `raw.jsonl` and `measurement-manifest.json`; `summarize.py` checks all 42 successful containers and produces `summary.json` and `summary.md`. A resumed collection skips existing case/backend/replicate records, so keep source, harness, and parameters unchanged when resuming. Any executable source change requires a fresh measurement.
