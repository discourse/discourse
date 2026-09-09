# Image-processing migration evidence

Completed operation evidence contains input fixtures, exact operation source files, a standalone benchmark harness, and raw results. Completed rendering evidence also includes both backend outputs. Earlier operation notes preserve their measured-source limitations; current publication and review status is recorded below. These artifacts support separate operation PRs; this evidence branch is not intended to merge into Discourse.

Benchmarks ran as the `discourse` user on the designated Linux server (2 CPUs, 2 GiB RAM), with Landlock enabled, in `discourse/base:2.0.20260812-0036` at digest `sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5`. This is the official launcher default; confirmation against the deployed image remains pending. Measurements include the actual operation wrapper, IPC, sandbox child, and codec work; Rails boot is excluded. Warm measurements alternate backends over 31 iterations per input. Five fresh-worker operation calls include both startup and conversion; they do not isolate startup cost.

For reproduction, create the bundle's `tmp` directory, install its locked gems into a separate mounted directory, and run `bundle exec ruby boot.rb` inside the pinned image with `RESULT_PATH` set to a writable JSON path. The bundle supplies minimal Rails configuration without loading the application. Do not substitute a host installation of ImageMagick or libvips.

Results are measurements of the supplied corpus on this machine, not a promise that every input becomes faster. Codec output differences, failures, and startup overhead must be considered alongside warm timing.

The JPEG, ICO, SVG asset, and topic OG bundles now include the returned Linux outputs and lockfiles. Their operation notes contain the full sample timing tables and known differences:

- [JPEG conversion](jpeg/README.md): ordinary inputs, explicit quality 75, ICC comparison, and a single stress timeout outcome.
- [HEIF conversion](heif/README.md): all seven measured 8/12-bit, alpha, container-transform, and photograph pairs, with latency and output-size differences.
- [ICO conversion](ico/README.md): exact decoded pixels for shared successful inputs, timing regressions, malformed input, and the RGB555 acceptance difference.
- [SVG asset rendering](svg-assets/README.md): all ten measured output pairs and timing regressions; the 75-megapixel dimension fixture is explicitly excluded.
- [Topic OG rendering](og/README.md): production before/after cards and timings; Arabic/CJK glyphs are missing from the pinned base image, so production text correctness remains unresolved.

Each of these directories keeps production outputs under `outputs/`, the measured bundle under `benchmark/`, and any supplementary development-environment captures under `local-dv/`. The development captures are not evidence of production font parity. The timing tables describe recorded snapshots and make no claim about final tests or PR CI.

All twelve operation draft PRs are published. See the [current head manifest](published-prs.json), [current source alignment](current-stack-source-alignment.md), and [final three-reviewer verdicts](review-final-verdicts.md). The source snapshots in each benchmark remain distinct from the extracted PR heads. The final cumulative source was reviewed by Grok, Claude Code and Codex; all three returned satisfied with no outstanding findings. Final CI is recorded separately in the head manifest.

[Native quality probing](quality/benchmark/RESULTS.md) now covers all three enabled-path quality callers. The 26 representative outcomes and 500-case JPEG matrix match the production ImageMagick helper. The [first-frame WebP supplement](webp-first-frame/README.md) covers compatible lossless geometry encoding, and the [crop-depth supplement](crop-depth/README.md) verifies the corrected 8-bit/16-bit metadata policy.

Geometry and orientation benchmark evidence is complete:

- [JPEG orientation](orientation/README.md)
- [Image downsize](downsize/README.md)
- [Thumbnail resize](resize/README.md)
- [North crop](crop/README.md)

The resize operation includes the user-approved removal of the unused `colors` option. Both backends now ignore that removed option; the historical colors12 cases are retained only as removed-API evidence and are excluded from migration performance claims. No PaletteImage or libimagequant dependency is introduced by the final resize branch.

Shared compatibility evidence includes the [80-case JPEG sampling comparison](jpeg-sampling/README.md) and [50-case SVG geometry comparison](svg-geometry/README.md). These supplements isolate encoding and background behavior; they do not supply operation timing or complete upload-pipeline measurements.

The [optimizer supplement](optimizer/README.md) records the final post-transform checks, including metadata changes, ICO byte preservation, and both sides of the PNG quantization threshold. The [review order](review-risk-order.md) ranks operations by risk separately from the stack merge order; the [remaining call-site audit](remaining-callsite-audit.md) records the completed enabled-path call-site audit.
