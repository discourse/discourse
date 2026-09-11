Run `bundle exec ruby /tmp/heif_benchmark.rb` from the PR checkout in a dedicated, otherwise idle Linux container with cgroup v2. The single script contains its bootstrap and calls the actual ImageMagick and DiscourseVips classes. It uses the repository HEIF fixtures and writes JPEG outputs to BENCHMARK_OUTPUT, defaulting to heif-benchmark-output in the working directory. It does not boot a full Rails application.

Each backend uses one Ruby child across the entire corpus. The native worker starts once and remains warm. Every input gets one warm-up call, 101 timed calls, and 101 separate memory calls. Timing excludes startup and memory sampling. Failed conversion attempts are measured and labeled as errors. The enabled path never falls back to ImageMagick.

Memory is the median sampled per-call peak increase over the idle baseline immediately before that call, using cgroup memory.current at a 1ms polling interval. Already allocated worker memory is excluded. New process, kernel, cache, output-file and coordinator charges are included. This is not Ruby heap allocation or RSS, and peaks between samples may be missed.

Production image: discourse/base:2.0.20260812-0036, digest sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5. UID/GID 1000, two CPUs, 2GiB memory and 3GiB combined memory/swap. Native JPEG output uses Q93 and optimized Huffman coding. Source hashes and output hashes are recorded separately.

The production image links libvips to JPEGli and ImageMagick to libjpeg-turbo. Their JPEG quality scales and quantization tables differ. Output sizes and common-reference pixel error comparisons describe this corpus; they do not establish universal visual equivalence. The calibration artifacts are separate from the final benchmark results.
