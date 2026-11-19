# Bundle analysis

Compares the core JS build of a PR with its base and comments on the PR when:

- code moves into the initial load (lazy code that now loads on every first page view),
- the initial load or another bundle grows over a threshold,
- a new bundle appears (a new `import()` target or entry),
- a bundle gains a new connection to another bundle (static, dynamic or URL import).

It is informational: findings never fail a PR, though the check itself fails if a build does.

## Terms

- **Bundle:** an entry (`discourse`, the media worker) or a lazy `import()` target (`admin`, the code editor, …).
- **Shared chunk:** an output chunk that dedupes code between bundles. Never reported on its own; its bytes count toward every bundle that loads it.
- **Initial load:** the `discourse` entry plus everything it imports statically.
- **Load cost:** a bundle plus what it loads beyond the initial load.

Sizes come from the bundle analyzer report that production builds write (`dist/assets/js/bundle-analysis-*.digested.json`). Bundle sizes are brotli quality 11, as production serves. Module sizes are rendered lengths before minification, so comment-heavy modules look larger than they ship. wasm and worker files are uncompressed.

## Running it locally

```sh
node script/bundle_analysis/analyze.mjs --base-ref origin/main --build-head
```

This builds the checkout and prints the full report and the PR comment it would post. The baseline is the merge base, built in a temporary worktree and cached in `tmp/bundle-analysis/`. Both are built as CI builds them (`EMBER_ENV=production CI=1`), so the comparison matches CI's.

## How CI runs it

- `.github/workflows/bundle-analysis.yml` runs on every PR to `main` with read-only permissions. A small job checks whether any JS input changed (`baseline.mjs --js-changed-since`) and whether the base has this analysis yet. Only then does it build the PR and its base side by side, each in a worktree (`baseline.mjs --commit`), then writes the full report to the run summary and uploads `report.json` as an artifact.
- `.github/workflows/bundle-analysis-comment.yml` runs on `workflow_run` from the default branch, so it can comment on PRs from forks. It treats the report as untrusted: it finds the PR from the workflow run, not the report, and renders the comment with its own copy of this directory and `budget.json`, which escapes every string and rejects anything but numbers where sizes belong.

A PR gets one comment, edited in place. A finding the comment did not have yet gets a new comment, because edits notify nobody. When nothing is over the thresholds any more, the comment says so.

## Files

- `budget.json`: thresholds. Changes take effect for PRs once merged.
- `lib/graph.mjs`: bundles, closures and connections from the bundle analyzer report, whose module graph `frontend/discourse/lib/bundle-graph.mjs` records.
- `lib/analyze.mjs`: compares two builds into a report of raw numbers.
- `lib/render.mjs`: applies thresholds and renders the comment and summary.
- `lib/comment.mjs`: the comment workflow's checks and comment lifecycle.
- `lib/baseline.mjs`: builds a baseline and checks for JS changes.

Tests: `node --test "script/bundle_analysis/test/*.test.mjs"`
