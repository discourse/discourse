# RSpec selection experiment

This draft observes runtime impact selection for core backend RSpec. It records
Ruby coverage around each example and unions the source files by spec file.
It follows the mechanism described by [Shopify](https://shopify.engineering/spark-joy-by-running-fewer-tests)
and [GitLab](https://docs.gitlab.com/development/pipelines/). Ruby Coverage is the
primitive also used by Crystalball. This implementation does not add its gem.

## CI flow

```text
Hourly workflow, serialized, one core backend job
  -> full core RSpec with coverage -> mapping artifact at commit A
PR at commit C
  -> latest successful mapping A, no exact base SHA requirement
  -> diff A..C, including main changes since A
  -> candidate specs -> full core RSpec -> compare candidate with failures
Other nine matrix entries, lint and migration workflows retain their full runs
```

The scheduled run reuses the existing backend setup. Collection does not happen
on every main commit. One missing mapping means a full selection, without making
another collector for each PR. Artifact expiry is seven days. Missing commits,
invalid artifacts and download errors produce a full selection.

For example, suppose mapping A connects `lib/url_helper.rb` to its own spec.
Main later changes `lib/slug.rb` to call that helper. A PR changes the helper.
Selection includes consumers of both files because both changed since A. A new
Ruby file with no recorded consumers causes a full selection. Configuration,
translations, database files, assets and other inputs outside the Ruby mapping
also cause a full selection. Changed, new and previously failing specs run.

This is an observed graph, not a proof of all possible Ruby dependencies.
Untaken branches, dependencies established at boot and work in other processes
can be absent. System tests remain full. Mapping a browser test would require
collecting from the Rails server and associating its coverage with the browser
example, as well as tracking JavaScript and assets.

## Measurement and promotion

`report.json` includes the selection, failed examples that it excluded, summed
example durations, worker CPU and selection latency. Excluded example seconds
are a potential saving, not measured runner CPU saved. Report missing worker
output and infrastructure failures separately from passing observations.

Before skipping anything, collect observations on real PR updates and confirm
failures by rerunning them to distinguish flakes. Require at least 20% net core
backend CPU savings, including artifact handling, collection amortized over PR
runs, selection and runner setup. Measure elapsed feedback time separately.
Require zero reproducible faulty PR updates wholly missed in at least 300
faulty updates for an approximate 95% upper bound of 1% on the miss rate. Zero
misses among passing PRs does not establish safety. Also report individual
failing examples missed, even if another selected spec catches the same PR.

After a separately reviewed rollout, use subsets only for intermediate PR
updates. Require a full current merge candidate before merge, retain full main
runs and randomly audit 10% of otherwise eligible updates. Keep full runs for
shared inputs, unknown sources and selector errors. Always include new tests. This draft has no
skip switch and changes no test command.

## Evidence and alternatives

A disposable Mac Studio sample ran eight existing spec files, with 165 examples
including one pending example. A helper mutation produced 33 failures. Using an
older mapping selected four sample files and caught all 33. Planning took 0.124
seconds and selected execution took 4.815 seconds, compared with 5.649 seconds
for the whole sample. These are single runs. Instrumented baseline collection
took 6.491 seconds. Repeated measurements at CI scale are needed to account for
collection, setup, artifact handling and sampling variability.

[Google's declared build graph](https://abseil.io/resources/swe-book/html/ch23.html)
can select reverse dependencies without recording test execution. Discourse has
no equivalent declared graph for Rails callbacks, constant loading and dynamic
method dispatch. Adding a build system alone would not supply those edges.

[Meta's prediction](https://engineering.fb.com/2018/11/21/developer-tools/predictive-test-selection/)
learns failure risk from history rather than treating every impacted test as
necessary. The alternative prediction draft experiments with that distinction.
The LLM alternative follows GitLab Duo's union with deterministic selections.
Neither published savings nor safety rates transfer to Discourse automatically.
`turbo_rspec` and runtime balancing distribute selected work. They do not decide
which tests may be omitted.
