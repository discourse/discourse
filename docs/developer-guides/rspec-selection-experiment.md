# RSpec failure prediction experiment

This alternative tests [Meta's high level mechanism](https://engineering.fb.com/2018/11/21/developer-tools/predictive-test-selection/):
learn which changes and tests are associated with failures, rather than running
every test with an observed dependency. It uses the existing
[scikit learn histogram gradient boosting classifier](https://scikit-learn.org/stable/modules/generated/sklearn.ensemble.HistGradientBoostingClassifier.html),
not an LLM. It is a smaller experiment, not Meta's production implementation.
Meta uses a build graph to generate candidates and much richer features. This
experiment scores the full core backend inventory because Discourse lacks that
declared graph.

## CI flow

```text
Previous full PR and main runs -> per spec outcomes and changed paths
Small Ubuntu job -> restore bounded recent history -> fit model -> plan artifact
Existing test matrix waits for that job -> backend reads the plan artifact
Existing full core RSpec -> compare selection with actual failures -> artifact
Other nine test matrix entries, lint and migration workflows stay full
```

There is no coverage collection or baseline commit mapping. A PR does not wait
for a matching base artifact. Features include previous failure frequency,
failures on overlapping changes, source and spec basename matches, number of
changed files and whether the spec itself changed. For example, repeated
failures in a model spec after changes to `lib/url_helper.rb` can teach the model
to select that consumer, despite different filenames. This depends on historical
failures. Runtime tracing can discover the dependency even if it never failed.

Only completed runs from this repository and the test workflow supply history.
The downloader considers up to 100 artifacts, uses at most 50 records and stops
starting requests after 20 seconds. Individual network calls may extend that
budget. Records are data, never executable model artifacts. No pickle is loaded.
The classifier trains on a separate Ubuntu runner with one CPU thread. Its
startup and scoring delay the test matrix. Failure to produce or download its
plan leaves full execution enabled. Backend reporting uses the CI image's
existing Python and needs no model dependencies. Dependency installation,
artifact retrieval, training and scoring are selection costs, not free work.

## Safety and measurement

The earliest 60% of records trains the model. The next 20% calibrates a threshold
that retains its failing specs. The final 20% tests that threshold on unseen
records. A subset requires at least five faulty test records and zero individual
failures missed in that held out segment. This is an experiment guard, not a
statistical safety claim. Configuration and other untraceable inputs, missing
history, one class training data, model errors and empty predictions select all.
New specs are mandatory. System tests stay full. New code paths without failure
history remain a central risk of this approach.

Every current test command still executes the full suite. The observation
artifact records missed failures, per spec durations, worker CPU and selector
latency. Group repeated runs by PR when evaluating safety, split by time and PR,
and confirm failures with retries before treating them as regressions. The
initial window split groups by run, so repeated revisions must be removed and
PR grouping added before using its score as a release gate.

Before allowing skips, require at least 20% net core backend CPU savings after
installation, history retrieval, training, scoring and unchanged CI setup.
Require zero faulty PR updates wholly missed among at least 300 independently
confirmed faulty updates for an approximate 95% upper bound of 1% on the miss
rate. Report individual missed failures separately. A corpus with mostly green
main builds cannot establish recall.

After a separately reviewed rollout, restrict subsets to intermediate PR
updates. Keep a full current merge candidate before merge, full main runs and a
10% random audit. This draft has no skip switch. The outcome collector was exercised with eight
existing spec files on a disposable Mac Studio environment: 165 examples, zero
failures and one pending example. With no history, the selector chose the full
inventory. Four model tests passed, including an actual classifier fit and
held out scoring. That unit data is deliberately synthetic and demonstrates
the model path, not accuracy on Discourse history.

Meta reported catching over 99.9% of faulty changes while running one third of
transitively dependent tests. That is published evidence for their deployment,
not an estimate for Discourse. This experiment cannot estimate savings until it
collects representative failed PR runs. Compared with the runtime mapping draft,
it avoids instrumentation cost and adds training and data maintenance.
`turbo_rspec` balances work across processes. It does not perform this selection.
