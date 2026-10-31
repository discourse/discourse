---
title: RSpec test selection in core CI
short_title: RSpec test selection
id: rspec-test-selection
---

Every push to `main` runs the full test matrix. Its core backend job uses
GitLab Crystalball coverage and described class strategies to map Ruby source
files to spec files. Capture includes outer context setup, nested contexts and
shared examples. Ruby File and IO reads record shared file inputs across every
example group, including integrity specs. Changing an observed input runs the
full core suite. This protects consumers of cached values, including native
accessors that execute no covered Ruby lines. Symlink reads record both the link
and its resolved target. Native extensions and external
process file reads are outside this instrumentation. The collector does not
propagate into nested test subprocesses.

The consumer records the expected worker identities and assigned files before
starting Turbo. Mapping publication requires complete matching worker records.
The merged `rspec-core-mapping-main` artifact includes its commit, dependencies,
shared bundle inputs, historical worker memberships and Ruby source structure checks. The newest usable main
producer is selected by workflow run ID. A failed producer or unreadable archive
does not replace an older usable artifact.

The artifact retains the input timing history used to assign its workers. PR
core preparation restores that history before grouping. This avoids making a
fresh mapping's worker membership obsolete merely by restoring the newer timings
produced during its own collection. Selection still handles assignment changes,
including new specs. Main keeps publishing complete runtime history through the
existing cache. PR core jobs cannot overwrite it with selected timings.

Only the PR core backend job prepares a selection, inside its existing container.
There is no separate selection runner or dependency that delays other jobs.
Preparation compares the mapping commit and PR base with the PR merge commit,
then takes the union of both change sets. It does not wait for an exact base
mapping. Missing artifacts, preparation failures and invalid plans run the full
core backend suite.

The selection starts with mapped consumers, new or modified specs, specs absent
from the mapping and backend integrity specs. Turbo computes its full current
worker assignment before selecting complete affected workers. It preserves their
file lists and database identities. Unchanged mandatory checks can run in their
original slots without selecting every other spec in those slots. Multisite keeps
its separate process and full inventory whenever an affected spec seeds a worker,
including when a deleted setup file leaves no regular candidates. Other test suites retain their
full commands. PR core timings cannot overwrite complete timing history.

Locale integrity specs follow their recorded dependencies instead of running on
every PR. Any locale YAML change runs the full suite, including additions under
plugins and documentation. This protects the locale directory discovery checks
while avoiding thousands of unrelated translation examples on frontend PRs.

A worker can populate a cache in one spec and read it in another without
executing the producer again. Line coverage alone would miss that dependency,
especially through native accessors such as `attr_reader`. Test order and worker
assignment can also change between collection and the PR.

Selection therefore includes every spec that shared a historical worker with a
directly affected spec. Turbo then selects complete current workers containing
those candidates. New, changed and unmapped specs also seed complete current
workers. The selected files are never redistributed. This protects conditional
cache warmers that start calling a producer after moving to a different worker.
It assumes application state is isolated between workers, as required by the
existing parallel runner.

Regular worker assignments and retry assignments supply these cohorts. The
initial multisite process does not seed additional regular workers, because its
complete context is already retained by full multisite execution. Collection
records its explicit inclusion tag before examples run to distinguish it from
retries, which also lack a regular worker number. All processes still contribute
dependencies, shared inputs and boot fingerprints.

For example, main runs `[a_spec, c_spec]` in worker 1. `a_spec` calls
`Producer.values` and fills a cache. `c_spec` finds that cache populated and never
calls Producer. A later assignment puts `c_spec` with `b_spec` in worker 2, where
`b_spec` consumes the cached value. Changing Producer includes the old worker's
`a_spec` and `c_spec`, then both current workers. Selecting only the direct
consumer's current worker would miss worker 2. This expansion can select most or
all of the core suite. Measure execution cost rather than direct consumer counts.

A complete mapping retains regular worker assignments even for spec files with no runnable root groups. It also identifies those empty files.
Unchanged empty files remain mandatory without forcing an entire worker. If a
file gains tests or is absent from the mapping, it seeds a complete current worker.

Unknown Ruby files, Ruby additions or deletions, configuration, dependencies,
database inputs, test support and unknown data paths run the full core suite.
Shared JavaScript bundle globs come from the existing PrettyText and asset
processor bundle definitions. Only explicit documentation, plugin, system spec
and Discourse frontend code paths are delegated to their existing jobs.
JSON and other unknown frontend data files are not ignored.
Observed plugin inputs, such as metadata and locales read by core tests, remain
shared inputs and require full core execution despite normal plugin delegation.

Ruby coverage alone cannot track every constant or generated Rails method.
Prism structure checks retain declarations and method signatures while removing
method bodies from a source fingerprint. Methods executed before the first
example group remain in the fingerprint too. The consumer verifies these checks
against the checked out source. A changed constant, Rails declaration, method
signature or boot method therefore runs the full core suite. A changed ordinary
method body can use the mapped selection. Unsafe intervening changes on `main`
also cause full execution because the old mapping may no longer describe them.

For example, editing the body of `UrlHelper.normalized_encode` can select its
recorded consumers. Adding an unmapped model or changing a model validation runs
the full core suite. This avoids assuming that all consumers are model specs.

Ten percent of otherwise selected revisions run the full core suite as an audit.
The audit reporter records all failing examples and those outside the predicted selection for their regular or multisite process,
including failures from shared context setup. Collection must include every
expected worker. Audit observations may include failures later recovered by
flaky test retries, so distinguish those from reproducible omitted regressions.

Preparation uses the existing workflow token with `actions: read`. That
permission applies to the build matrix job, including its other legs, because
GitHub does not scope permissions to individual steps. No new secret is needed.

Repository variables control new runs:

| Variable                        | Default  | Behavior                                                                                                                         |
| ------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `RSPEC_SELECTION_MODE`          | `select` | Use selection and sampled audits. `audit` runs every predicted subset as a full audit. `full` disables selection and collection. |
| `RSPEC_SELECTION_AUDIT_PERCENT` | `10`     | Integer from 0 to 100. Invalid values select full execution.                                                                     |

Fork PRs use full execution when selection mode configuration is unavailable.
This avoids relying on base repository variables being delivered to fork runs
for the emergency full control. Same repository PRs default to `select`.

The `rspec-core-selection-report` artifact contains the prediction and actual
execution report. Reports include revision, actual mode, selected and available
regular file counts, multisite inventory, selection duration, CPU time, elapsed
time, exit status and audit omissions. The execution plan records exact assigned
and predicted files. Wrapper CPU includes Ruby plan validation and child
processes, excluding database and Redis services. When cgroup version 2
metrics are available at the cgroup namespace root, CPU includes all processes in
that cgroup. This includes database and Redis services in an isolated container.
Metrics are omitted when the process belongs to a nested visible cgroup, rather
than accidentally measuring its host's root cgroup. Selection records the same
scope. Compare allocated runner time as well, since waiting for
selection holds the runner's capacity. Use these to measure both missed failures and total compute. Count
tracing and publication on every main run, PR selection, audits, fallbacks and
retries. A smaller file count alone does not prove savings.

Use `audit` for a rollout that observes all PRs before skipping. Investigate every
reproducible omission and set `full` while correcting a selection defect. The
local replay harness exercises the actual collector, preparation and consumer
with disposable Git histories and local artifact transport. GitHub service
latency and artifact permissions still require CI verification.
No finite replay matrix proves that all future regressions will be detected.
