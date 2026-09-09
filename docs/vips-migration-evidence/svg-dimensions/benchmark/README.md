# SVG dimensions benchmark

This standalone bundle copies the real ImageMagick wrapper, libvips facade,
worker and supporting files from `4a5ceb55d43`. `source-manifest.json` records
source SHA-256 values. It contains no Rails application boot or vendored gems.

Install the exact versions in `Gemfile` in the benchmark environment, including
Nokogiri 1.19.4 and Racc 1.8.1. Native libvips with librsvg, ImageMagick with
MSVG, and Linux Landlock are required. The parent task owns environment setup
and execution.

Run from this directory:

```sh
bundle exec ruby boot.rb
```

Set `RESULT_PATH` to choose the report destination; the default is
`svg-dimensions-results.json` in this directory. Preserve the `tmp` directory
when copying the bundle because the actual worker creates its socket there.

The report records nine expected-success cases and four expected-rejection
cases separately, retaining every outcome, input SHA-256, source SHA-256,
versions, and timing samples. Each input has one warmup per backend followed
by 31 measured iterations whose backend order alternates. Five additional
calls measure creation of a fresh libvips worker and one fixed-size SVG
request. Cold measurements exclude the Ruby bootstrap and do not reset OS
caches. Every ImageMagick call starts a command, as it does in production.

The legacy operation is the actual wrapper's `identify -ping -format %w,%h
MSVG:<path>`; the new operation is `DiscourseVips.svg_dimensions` with the same
five-second timeout. All successful dimensions must match the explicit
expected pair. Invalid cases must raise; errors are not converted into zero
dimensions. The harness saves the full report before exiting unsuccessfully
if any outcome differs, including an invalid input accepted by either backend.
Such differences must be inspected rather than folded into successful timing
comparisons. Header-only acceptance of malformed SVG may differ by renderer.

The previous eight-success/four-invalid bundle passed parent execution.
The added whitespace sample and updated worker await parent execution. The copied sources were
checked byte-for-byte against the dedicated SVG-dimensions worktree.
