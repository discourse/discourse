# CI runtime experiment

Reach 480 seconds elapsed from PR workflow creation until the last applicable
check completes. Track queued time, aggregate runner seconds, runner capacity,
and peak job-container memory separately. Record OOM counters and test retries.
Preserve the complete test matrix, test selection, assertions, retries, and
failure reporting. Keep the existing job count and test groups; do not split
tests into additional jobs. A skipped test suite is not a successful optimization.

Use this draft PR as the measurement environment. Keep the base revision fixed
at 0708de39bcebe79c8469dfd88cd568c8e71b42c7 during the experiment. Record external
plugin/theme revisions and cache behavior when assessing noisy results.
Temporarily check out this PR head during measurements so updates to main do not
change the tested sources. Remove the checkout pin before final merge validation.

## Procedure

1. Measure the original workflows on this documentation-only baseline commit.
2. Change one optimization at a time and push one candidate revision.
3. Launch a CI watcher pinned to the new PR head and wait for its
   verdict. Collect completed workflow and job timings for that exact revision.
4. Reject failures and coverage reductions. Keep measured improvements; revert
   regressions with a new commit. Keep every experiment on this PR. Use commit
   messages to record hypotheses, prior run IDs, summarized timings, and decisions.
   Keep detailed test counts, retries, and raw evidence in the local experiment log.
5. Repeat the best candidate to distinguish improvement from runner variation.
   Require three complete successful measurements at or below 480 seconds before
   declaring the target achieved. Report every measurement, including outliers.

Initial experiment budget: six candidate revisions, plus baseline and
confirmation measurements, unless the user changes this limit.

## Initial observations

Main Tests run 34313007095 took approximately 13 minutes. Its core system-test
step took 690 seconds and core backend RSpec took 512 seconds. Setup overlap
alone cannot reach the target. Explore worker utilization, runtime-based balancing,
and setup efficiency within the existing jobs. Do not add test jobs.

This file establishes a baseline without changing workflow behavior. Local
measurement scripts and raw results live beside it and are excluded from commits.
The experiment follows https://github.com/davebcn87/pi-autoresearch using Codex
as the coordinator and GitHub Actions as the benchmark executor.
