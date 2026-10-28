---
title: RSpec test selection in core CI
short_title: RSpec test selection
id: rspec-test-selection
---

Every push to `main` runs the full test matrix. Its core backend job uses
Ruby coverage tracing to map source files to spec files.
Capture covers each outer example group, including nested contexts, shared
examples and `before(:context)` setup such as `fab!`.

Worker mappings are merged into the `rspec-core-mapping-main` Actions artifact.
Each artifact includes its source commit. Artifacts are immutable, so the
selector treats the newest successful core backend job as the current mapping.
Other jobs in that producer workflow need not succeed.
A failed or unfinished producer does not replace the previous usable mapping.

For a PR targeting `main`, one preparation job downloads the mapping and
compares its commit with the PR merge commit. It also compares the PR base
with the merge commit, so PR changes remain included when they cancel changes
since the mapping. This includes intervening changes on `main`.
It selects the union of:

1. Specs mapped to changed source paths, including deleted paths.
2. New or modified specs and specs missing from the mapping.
3. Backend integrity specs, which read frontend and plugin files directly.
4. A broader subsystem for unmapped Ruby files: `lib/` selects `spec/lib/`,
   and `app/models/` selects `spec/models/`, for example.

The core backend job downloads that selection. `bin/turbo_rspec` distributes
the selected files among its existing workers, including the multisite worker.
An empty selection exits without starting RSpec. PR core backend jobs restore
runtime timings without saving their partial logs over the full history.
Other matrix jobs retain their existing full test commands. PRs targeting other branches also retain full runs.

PR changes to shared configuration, dependency files, database changes, test
support, themes and unknown file types select the full core backend suite.
The mapping also includes shared JavaScript bundle input globs from `PrettyText::CoreBundle` and
`AssetProcessor`, so changes to those inputs run backend tests too.
A missing, invalid or unavailable mapping also runs the full suite. Other frontend, plugin,
documentation and system spec paths do not independently select core backend
specs because their existing jobs still run.

For example, changing `lib/url_helper.rb` selects every spec recorded as using
it. Adding an unmapped `app/models/topic_formatter.rb` selects model specs plus
any specs selected by other changed paths. This subsystem rule is a heuristic:
an older mapping cannot reveal every new dependency introduced by a PR.
Broad fallback rules apply to the PR's own changes. Intervening changes on
`main` contribute mapped consumers and changed specs, while full `main` runs
verify their shared configuration changes. This avoids repeatedly running the
full suite on PRs just because the mapping is behind `main`.
Full runs on `main` remain necessary to detect regressions missed before merge.

The preparation job reports selected file count and selection duration.
Compare total CI runner usage, including tracing on `main`, with the previous
full runs. A smaller spec count alone does not establish a compute saving.
When a failure appears on `main`, check the PR selection artifact to determine
whether selection omitted that spec. Results must account for intermittent
failures and changes merged since the PR was tested.
