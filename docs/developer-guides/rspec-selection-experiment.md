# LLM assisted RSpec selection experiment

This alternative follows [GitLab Duo's selection mechanism](https://docs.gitlab.com/development/pipelines/#gitlab-duo-system-test-selection):
union an LLM proposal with deterministic selection and choose the full suite on
uncertainty or failure. GitLab applies Duo to system specs. This draft starts
with core backend RSpec to compare against the runtime mapping experiment in
one bounded scope. It does not reproduce GitLab's product or prompts.

## CI flow

```text
Trusted PR target workflow reads diff and spec inventory as data
  -> configured model, one bounded request -> proposal tied to PR head and base
Hourly core backend collector -> runtime dependency artifact
Ordinary PR test job -> runtime selection UNION model proposal
  -> full core RSpec -> compare proposed set with actual failures
```

The model endpoint, model name and optional token use `RSPEC_LLM_URL`,
`RSPEC_LLM_MODEL` and `RSPEC_LLM_TOKEN` repository configuration. The first two
are Actions variables. The token is an Actions secret. Configure the endpoint
for a provider that accepts chat completion requests. No provider or token is
committed. Missing configuration produces a full selection.

The model request runs from the trusted base checkout. It never checks out or
executes PR code. PR patches are JSON data. The secret does not enter the PR
build. The target workflow has read permissions and uploads only a proposal.
Treat model output as untrusted. The consumer verifies its workflow, repository,
PR head and base, and each proposed path against the actual spec inventory.

For example, an older mapping connects `lib/url_helper.rb` to its consumers.
The deterministic floor selects those specs. A model inspecting the helper diff
can add a spec whose relationship is absent from that recording. It cannot
remove a recorded consumer. A confident empty proposal retains the deterministic
floor. An uncertain, invalid or missing proposal selects all. An unmapped source
or shared configuration change already requires all specs and cannot be
narrowed by the model.

## Cost and limits

The request caps input at 100 KB and output at 2000 tokens. Incomplete patches
and larger changes fall back to full selection. The HTTP timeout is 20 seconds
and the proposal workflow has a two minute timeout. Token counts and model
latency are retained in `report.json` when the proposal is accepted. Include
failed requests, runner startup, proposal workflow scheduling and artifact
handling when accounting for cost. Token prices depend on the configured model.

The PR job uses a completed proposal if available after its existing setup. It
does not wait for one. An unavailable proposal costs a full selection. A new base
SHA invalidates a semantic proposal, while the runtime mapping can be older and
still include every changed path since its recorded revision. The hourly
collector is serialized and does not run for every main commit.

Diff and filenames can omit the context needed to discover indirect Ruby
consumers. The model's uncertainty flag is not a calibrated safety estimate.
Prompt injection can alter suggestions despite the instruction to treat code as
data. The deterministic floor and observation phase limit the consequence.
System and frontend tests remain full, including cross process behavior that
backend coverage cannot map.

## Evaluation

All existing test commands still run the full suite. Report graph selection,
union selection, reproducible failures missed by each, selection latency, model
usage and whole workflow CPU. This makes the LLM's incremental value measurable:
it must catch otherwise missed failures at a cost below the compute saving.
A union cannot reduce execution further than its deterministic floor. The LLM
must justify itself through better failure detection, not smaller subsets.

Before skips, require at least 20% net core backend CPU savings after collection,
model calls and selection, and zero faulty PR updates wholly missed among at
least 300 independently confirmed faulty updates. This gives an approximate 95%
upper bound of 1% on the miss rate. Report individual failures missed separately.
Keep full current merge candidate runs, full main runs and a 10% random audit
when a separately reviewed rollout permits subsets on intermediate updates.
This draft has no skip switch.

The transport tests use a local HTTP server and synthetic replies. A live model
request also used the helper mutation from the eight file runtime trial. It
proposed only `spec/lib/url_helper_spec.rb`, with 384 input tokens, 506 output
tokens (including reasoning) and 4.80 seconds of model latency. The full sample
had 33 failing examples. Eleven were in the proposed spec file, leaving 22
individual failures outside the LLM proposal. The runtime selection caught all 33. Unioning this proposal added no tests and no additional failure detection.
This single bounded input does not establish general model accuracy. It shows
why incremental benefit and inference cost need measurement before adoption.
Real model accuracy and cost need a replay over representative PR failures.
[Meta's failure prediction](https://engineering.fb.com/2018/11/21/developer-tools/predictive-test-selection/)
is the other alternative, using historical outcomes instead of semantic model
inference. `turbo_rspec` distributes selected files and remains independent of
these selection decisions.
