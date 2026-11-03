# Bundle analysis

Compares the core JS build of a PR with its base and comments on the PR when:

- code moves into the initial load (lazy code that now loads on every first page view),
- the initial load or another bundle grows over a threshold,
- a new bundle appears (a new `import()` target or entry),
- a bundle gains a new connection to another bundle (static, dynamic or URL import).

It is informational only and never fails a PR.

## Terms

- **Bundle:** an entry (`discourse`, the media worker) or a lazy `import()` target (`admin`, the code editor, …).
- **Shared chunk:** an output chunk that dedupes code between bundles. Never reported on its own; its bytes count toward every bundle that loads it.
- **Initial load:** the `discourse` entry plus everything it imports statically.
- **Load cost:** a bundle plus what it loads beyond the initial load.

Bundle sizes are brotli quality 11, as production serves. Module sizes are minified bytes.

## Running it locally

```sh
cd frontend/discourse && EMBER_ENV=production pnpm build && cd ../..
node script/bundle_analysis/analyze.mjs --base-ref origin/main --head frontend/discourse/dist
```

This prints the full report and the PR comment it would post. The baseline is the published build of the merge base when one exists, else the merge base is built in a temporary worktree. Baselines are cached in `tmp/bundle-analysis/`.

## How CI runs it

- `.github/workflows/bundle-analysis.yml` runs on every PR to `main` with read-only permissions. A small job checks whether any JS input changed (`baseline.mjs --js-changed-since`). Only then does it build the PR, find the baseline (`baseline.mjs --commit`), write the full report to the run summary and upload `report.json` as an artifact.
- `.github/workflows/bundle-analysis-comment.yml` runs on `workflow_run` from the default branch, so it can comment on PRs from forks. It treats the artifact as untrusted: it checks it against the workflow run and the PR, validates the report (`lib/validate.mjs`) and renders the comment with its own copy of this directory and `budget.json`.

A PR gets one comment, edited in place. A finding the comment did not have yet gets a new comment, because edits notify nobody. When nothing is over the thresholds any more, the comment says so.

Baselines are exact because the build is reproducible: a weekly job (`reproducibility.mjs`) rebuilds a published commit and fails if anything differs.

## Files

- `budget.json`: thresholds. Changes take effect for PRs once merged.
- `lib/graph.mjs`: bundles, closures and connections from `dist/manifest/bundle-graph.json`, which `frontend/discourse/lib/bundle-graph-plugin.mjs` writes in production builds.
- `lib/analyze.mjs`: compares two builds into a report of raw numbers.
- `lib/render.mjs`: applies thresholds and renders the comment and summary.
- `lib/comment.mjs`: the comment workflow's checks and comment lifecycle.
- `lib/baseline.mjs`: finds or builds a baseline.

Tests: `node --test "script/bundle_analysis/test/*.test.mjs"`
