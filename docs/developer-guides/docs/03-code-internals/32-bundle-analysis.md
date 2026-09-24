---
title: Inspecting JavaScript bundle sizes
short_title: Bundle analysis
id: bundle-analysis
---

The bundle visualiser and the Node CLI read the same core build report. No running
Discourse server is needed for the CLI. Build production assets to measure the
minified code and its Brotli transfer size:

```sh
pnpm install --frozen-lockfile
EMBER_ENV=production pnpm build
node script/bundle-analysis.mjs summary
node script/bundle-analysis.mjs summary --entry discourse --top 20
node script/bundle-analysis.mjs summary --entry admin --json
```

`summary` accepts a build directory or a core `bundle-analysis-*.digested.json`
file. It defaults to `frontend/discourse/dist`, following the current report's
path in `manifest/manifest.json`. It lists regular and dynamic entrypoints.
`--entry` selects a logical name or a full chunk filename. JSON output includes
all contributing modules; `--top` limits module lists in text output only.
Development reports are also readable, but their Brotli sizes are unavailable.

Each total includes the entrypoint and all of its transitive **static** imports,
counting shared chunks once. Dynamic imports are excluded. Different entrypoint
totals overlap: do not add them together to estimate a page's size. Module
`renderedLength` values explain contributions, but are not compressed byte sizes.
These reports do not include plugin bundles or the browser's runtime loaded state.
Plugin reports remain available at
`app/assets/generated/<plugin>/bundle-analysis.json`.

## Comparing builds

Keep the report from each production build, then run:

```sh
node script/bundle-analysis.mjs diff base.json pr.json
node script/bundle-analysis.mjs diff base.json pr.json --json
node script/bundle-analysis.mjs diff base.json pr.json --entry discourse --percent 10 --bytes 25600
```

Build directories work as inputs too. Use the same Node/Brotli versions and build
flags for both revisions, installing each revision's dependencies from its lockfile.
The diff matches entrypoints by logical name, so changing content hashes does not
break comparisons. It reports raw and Brotli totals and the largest changes in
module contributions, including modules added to or removed from the static graph.

The default gate fails if the `discourse` static dependency total grows by **both
at least 10% and at least 25 KiB (25600 bytes)** in Brotli size. Equality hits the
threshold; unchanged or smaller bundles pass. Adjust `--percent` and `--bytes`
together to change the gate. Raw sizes are diagnostic and do not trigger failure.

Exit codes are `0` for success, `1` for a size regression, and `2` for invalid
arguments or reports. Comparisons reject development reports, missing entrypoints
or static dependencies, and missing Brotli sizes.

## GitHub Actions

The `Bundle size` workflow independently builds the exact PR base commit and the
PR merge commit with `EMBER_ENV=production`. It measures core JavaScript only,
using `pnpm build`; it does not need Rails, databases, or plugin compilation.
The `Bundle size comparison` job applies the thresholds specified in
`.github/workflows/bundle-size.yml`. A failed build also fails this job.

The workflow retains `bundle-size-base` and `bundle-size-pr` artifacts for 14 days.
Each contains `report.json` and `build.json` with the commit and runtime versions.
Download both artifacts to reproduce the comparison locally. The comparison's
text output appears in the job summary, including when a size regression fails it.
Both revisions must contain the visualiser's report generator; missing reports
fail explicitly. To require this gate before merging, select `Bundle size
comparison` in the repository's branch protection settings.

Run the CLI's tests with:

```sh
node --test script/bundle-analysis.test.mjs
```
