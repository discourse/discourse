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
shared bundle inputs, worker execution orders and Ruby source structure checks. The newest usable main
producer is selected by workflow run ID. A failed producer or unreadable archive
does not replace an older usable artifact.

Only the PR core backend job prepares a selection, inside its existing container.
There is no separate selection runner or dependency that delays other jobs.
Preparation compares the mapping commit and PR base with the PR merge commit,
then takes the union of both change sets. It does not wait for an exact base
mapping. Missing artifacts, preparation failures and invalid plans run the full
core backend suite.

The selection includes mapped consumers, new or modified specs, specs absent
from the mapping and backend integrity specs. Turbo distributes the chosen files
using its existing workers and multisite pass. Other test suites retain their
full commands. PR core timings cannot overwrite complete timing history.

Locale integrity specs follow their recorded dependencies instead of running on
every PR. Any locale YAML change runs the full suite, including additions under
plugins and documentation. This protects the locale directory discovery checks
while avoiding thousands of unrelated translation examples on frontend PRs.

A worker can populate a cache in one spec and read it later without executing the
producer again. Line coverage alone would miss that later dependency, especially
through native accessors such as `attr_reader`. The mapping retains each worker's
observed root group order, including repeated spec filenames. When a source affects a spec, selection also includes every
later spec in that worker. This protects cached consumers without tracing every
method call or marking every cache owner as a global input. Retaining repeated
filenames protects a consumer file whose groups run both before and after a
producer. Retry and multisite workers contribute their own orders. Worker
suffixes assume application state is isolated between workers, as required by
the existing parallel runner.

For example, worker 1 runs `[a_spec, b_spec, c_spec]`. `a_spec` calls
`Producer.values` and stores the result in `Reader`. `c_spec` reads `Reader.values`
without calling `Producer`. Changing the body of `Producer.values` selects all
three specs from worker 1. An unrelated worker remains eligible to skip its
specs. Early dependencies can therefore select a large worker suffix. Reports
must measure this execution cost rather than counting only direct consumers.

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
The audit reporter records all failing examples and those outside the predicted selection,
including failures from shared context setup. Collection must include every
expected worker. Audit observations may include failures later recovered by
flaky test retries, so distinguish those from reproducible omitted regressions.

Preparation uses the existing workflow token with `actions: read`. That
permission applies to the build matrix job, including its other legs, because
GitHub does not scope permissions to individual steps. No new secret is needed.

Repository variables control new runs:

| Variable                        | Default  | Behavior                                                                                                          |
| ------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------- |
| `RSPEC_SELECTION_MODE`          | `select` | Use selection and sampled audits. `audit` runs every predicted subset as a full audit. `full` disables selection. |
| `RSPEC_SELECTION_AUDIT_PERCENT` | `10`     | Integer from 0 to 100. Invalid values select full execution.                                                      |

Fork PRs use full execution when selection mode configuration is unavailable.
This avoids relying on base repository variables being delivered to fork runs
for the emergency full control. Same repository PRs default to `select`.

The `rspec-core-selection-report` artifact contains the prediction and actual
execution report. Reports include revision, actual mode, selected and available
file counts, selection duration, CPU time, elapsed time, exit status and audit
omissions. Worker CPU excludes database and Redis services. When cgroup version 2
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
