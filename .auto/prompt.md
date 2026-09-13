# CI runtime experiment

Reach 480 seconds elapsed from PR workflow creation until the last applicable
check completes. Track queued time, aggregate runner seconds, runner capacity,
and peak job-container memory separately. Record OOM counters and test retries.
Preserve the complete test matrix, test selection, assertions, retries, and
failure reporting. Keep the existing job count and test groups; do not split
tests into additional jobs. A skipped test suite is not a successful optimization.

Use this draft PR as the measurement environment. Controlled measurements used
base revision 0708de39bcebe79c8469dfd88cd568c8e71b42c7 and a temporary PR-head
checkout. Subsequent measurements use normal PR merge checkout, including current
main. Record the actual tested revision and distinguish source changes from
optimization effects. Record external plugin/theme revisions and cache behavior
when assessing noisy results. Detailed profilers have been removed; retain job
memory and CPU totals for the resource comparison.

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

Continue experiments until the eight-minute goal is achieved. There is no
experiment-count limit. Preserve the existing jobs and complete test coverage.

## Initial observations

Main Tests run 34313007095 took approximately 13 minutes. Its core system-test
step took 690 seconds and core backend RSpec took 512 seconds. Setup overlap
alone cannot reach the target. Explore worker utilization, runtime-based balancing,
and setup efficiency within the existing jobs. Do not add test jobs.

The first six-candidate run did not reach 480 seconds. Its best controlled run
was 636 seconds with no retries and matching test counts. Dependency overlap saved
2-10 seconds per job, and recorded timings improved theme worker balancing.
Backend YJIT and fourteen core-system workers were reverted after showing no
measured benefit and higher memory use. Twelve core-system workers remain
provisional because execution times varied substantially.

Local measurement scripts and raw results are excluded from commits. The commit
history records each candidate, measurement and revert.
The experiment follows https://github.com/davebcn87/pi-autoresearch using Codex
as the coordinator and GitHub Actions as the benchmark executor.
