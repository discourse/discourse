# Local RSpec selection experiment

Run inside the existing Discourse test environment, with its dependencies,
PostgreSQL and Redis available:

```sh
python3 script/ci/rspec_selection_lab/run.py \
  --directory /experiment/harness/run-001
```

The directory must be new and outside the source checkout. The harness creates
an independent Git repository and a local bare origin inside it. It copies
the current source, including local changes. Source files remain unchanged.
Ignored dependency and configuration paths may be linked to the source.
Tests use the environment's disposable test databases, so runs must be serialized.
Snapshots require at least 8 GiB and 15 percent free disk space. Low disk
space can disable remote image downloads inside Discourse and invalidate a
baseline. Retained snapshots and compiled dependencies consume this reserve.
The snapshot copies generated uploads referenced by the existing seeded databases.
RSpec runs set `CI=true` for eager loading and `GITHUB_ACTIONS=true`, matching the
production backend environment. Bytecode caches are excluded from source copies.
RSpec preloads the CI allocator when `RUBY_ALLOCATOR` is configured.

The default inventory contains fourteen existing core spec files and thirteen synthetic
dependency probes. Other core spec files are removed from the disposable copy
before recording its baseline. Every full comparison uses this bounded inventory.
The probes exercise directory discovery, data reads, constants, cached boot values,
password consumers and a separate model spec.
They expose dependency gaps through actual Rails and RSpec execution.
The collector integration includes a consumer file whose root groups straddle
a cache producer under RSpec random seed 10.
Use `--ci-bootstrap` to install the locked frontend dependencies, compile backend
bundles, and remove dependency directories during tests as CI does. Each changed
scenario rebuilds those bundles before comparing test results.
Use `--all-specs` for the complete core inventory. To measure collection capacity
without running every scenario:

```sh
python3 script/ci/rspec_selection_lab/run.py \
  --directory /experiment/harness/full-001 \
  --all-specs --baseline-only --ci-bootstrap --timeout-seconds 1800
```

Use `--scenario mapped_helper` to run one comparison. Repeat that option to
choose several scenarios. Complete inventory runs require explicit scenarios
unless `--baseline-only` is set, to prevent accidental repeated full suites.

Both modes execute the real `rspec_selection.rb run` command and Turbo workers.
The traced main run uses the real collector and merge command. The harness
archives the merged mapping and calls the real `prepare` function, using local
artifact bytes and simulated Actions metadata. Git comparisons and fetches use
the disposable repositories. No GitHub credentials or requests are needed.

The default run includes 65 general scenarios and five focused worker context cases. The general scenarios cover helper regressions, native accessor caches, delegated cache producers, new plugin locales, model validation, controller responses,
scheduled jobs, template rendering, simultaneous changes, changed and
new specs, spec renames and deletions, source renames, shared support, fabricators,
routes, locales, dependencies, bundles, views, database structure, CI configuration,
stale mappings, reverted specs and artifact failures. A generated migration
checks the existing pending migration guard without applying database changes. Artifact cases include
expired or oversized archives, producer identity, revision mismatches, missing
ZIP members, invalid schemas and missing spec entries. Consumer cases exercise
missing, corrupt and stale selection files.

Two discovery probes check changes that execution coverage may not record:
a new model file found through a directory scan and a changed JSON file read
by Ruby. JavaScript probes exercise a direct Ruby read, a boot read and the
compiled server bundle. These are ordinary scenarios. Any omitted failure makes the report
fail, even if the gap is a known limitation.
A negative control deliberately discards affected worker candidates from the prediction. An audit
control checks that a full sampled run reports those omitted failures. The harness
must detect omitted failures for that control to pass.

The worker context cases share one disposable source checkout, retaining each
case revision as a Git commit. They change ordering, reassign workers and introduce new or
changed specs that expose failures in a neighbouring test. Each compares the
actual full and selected runner, preserves worker identities and file assignments,
and must expose an omission when its selection is deliberately weakened. A deleted setup file case checks multisite selection when no regular candidates remain. The
reassignment audit also checks that full multisite selection cannot hide a regular
worker omission. Run just these cases with:

```sh
python3 script/ci/rspec_selection_lab/cohort_cases.py \
  --directory /experiment/harness/cohorts-001
```

`report.json` contains selected files, example failure identifiers, worker seeds,
exit codes, elapsed time and CPU time. Every worker writes structured results.
Unexpected infrastructure errors stop the experiment. Each phase has a time
limit and its process group is terminated if that limit expires.

On Linux with cgroup version 2 and a namespace root identity of `0::/`, CPU
measurements cover every process in that cgroup. Run in an exclusive container to
include database and Redis without unrelated work. Reports retain that identity
and child process CPU. Other cgroup layouts omit these broader measurements. Elsewhere the
report explicitly identifies its narrower CPU scope. Allocated CPU seconds use
the container quota or available CPU affinity multiplied by elapsed time.

CPU accounting defaults to one main run for each PR run, including the cost of
collection and publication on every main push. Use `--pr-runs-per-main 3` to model
three PR runs per main push. This is a workload model, not measured production
traffic. Sampled audits in the matrix are explicit scenarios.
It includes mapping merge, artifact
packaging and selection. The negative control and experiment setup are excluded.
The mapping input timing history is restored and worker seed 123 is enforced before
each general comparison. Focused cases deliberately override that history and use
different seeds to exercise ordering and assignment changes. Execution order alternates, but application and filesystem
caches are not controlled. A single
bounded run cannot establish production savings or a missed regression rate.
Local artifact transport does not measure GitHub service latency or permissions.

The experiment directory contains its ownership marker, repositories, artifacts,
logs and results. Retain it for inspection, then remove only that owned directory
after ensuring no experiment process remains. Dependencies, shared images and
the source checkout are not owned by this harness.

`act` can supplement workflow checks. Its [local artifact service](https://nektosact.com/usage/index.html#action-artifacts)
does not support downloads from another workflow run. Its concurrency, permissions
and timeout behavior also differs from GitHub Actions. Those boundaries need
separate verification before production use.
