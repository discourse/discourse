# CI test file selection

CI prepares a file plan before starting test jobs. The plan identifies the application revision, selected test files, reasons for selecting each file, and the environments that own those files. Jobs receive explicit file lists. Turbo distributes those files without expanding the selection.

The tests workflow covers core and plugin RSpec, five system test environments, core and plugin QUnit, theme QUnit and Vitest. The migration workflow uses the same planner for each migration gem, both without Rails and with Rails integration. Database setup, schema checks, annotations and other mandatory checks keep their existing responsibilities.

## Selection rules

A PR always includes added and changed tests. A renamed test runs at its destination and a deleted test is omitted. Every changed test file protects its complete owning environment. Other environments can still receive empty assignments. This is a deliberate efficiency limitation within the affected environment.

RSpec definitions are globally visible through its registry. An unchanged reader can call a writer's memoized helper or inspect group metadata. Magic comments, leading blank lines and heredoc payloads also affect those definitions. For example, adding `# frozen_string_literal: true` can make a registered helper return a frozen string, and an unchanged reader that mutates it then fails. The writer can still pass alone. Normalizing only statements or assertion bodies would miss that reader.

Frontend test files can also affect shared state. In the browser replay, a QUnit writer changes a global value while its own assertion passes. An unchanged reader fails when both files run. The planner protects the full owning frontend environment so that reader remains selected.

A file change therefore needs no content classification before protecting its RSpec owners. Even adding a preloaded helper require can shift `__LINE__` or group line metadata. Deleted files use base commit inventories to identify previous owners. Documentation outside test files does not add tests. These rules apply to every PR target branch.

For application changes, the planner checks which test files differ between the mapping producer and the PR base. Any such file in the environment protects that complete environment because the old mapping cannot establish its current shared effects. Main might add a hook that connects a producer to an existing reader after collection. Main always runs every file, and audits compare candidate execution with the complete reference. Frequent test changes on main limit how often an older dependency mapping can narrow application PRs. The evidence report records conservative extra execution separately from precise dependency selections.

Ownership validation uses the complete test inventory before routing files to either workflow. Core frontend helpers are application inputs rather than runnable test files, even when their filenames end in `-test.js`.

For application changes, the planner combines the PR diff with files touched between the mapping producer and the PR base. It traverses recorded source dependencies and selects their test consumers. It also selects tests changed since collection. The mapping can precede or follow the PR base. No job waits for a mapping produced at one exact commit.

For example, the cache replay changes a producer from `:original` to `:broken`. The writer stores its value and the reader consumes it. Both specs run, while an unrelated username spec is omitted. This replay uses the real Discourse hooks. More complex application methods can require the full inventory because their effects remain uncertain. In particular, a `UrlHelper` change does not promise a subset.

A missing mapping, unexplained inventory change, new application file or unverified source change selects the full inventory for the affected environment. Changes to declarations, method signatures, dependency operations, control flow or code executed during initialization require broader execution. Initialization and uncertain effects protect the method that caused them. Other methods in the same file can still use their mapping. Initializers, shared file reads and uncertain state changes also broaden selection. Every selected file records the reason.

Examples whose bodies are defined outside the mapped spec sources also protect their producer initialization. Application work outside a test or on another thread is also protected, because execution time alone cannot establish which file initiated it. Ruby request paths served on separate threads can therefore require full system execution.

Main always runs every file in each environment.

## Mapping collection

A separate main push workflow collects backend and migration RSpec mappings. Required main test jobs run the full suite without tracing. The producer is serialized and checks the latest completed bundles before recording. `TEST_MAPPING_INTERVAL_SECONDS` defaults to `86400`, so busy main branches reuse the last completed mapping while accounting for later changes. Failed collection never replaces a successful bundle. Producer jobs have a separate six hour limit and allow 180 seconds per example during tracing. Required jobs retain their existing limits, including 45 seconds per example.

The producer collects Crystalball coverage and described class dependencies per test file. A Ruby trace supplements coverage with executed calls, native accessors and block methods. Calls retain source relationships across tests, including writes to a cache defined in another file. Returned mutable containers retain source ownership so indexed cache writes can connect to later readers. Detected unowned state changes and dynamic initialization are treated conservatively.

RSpec context fixtures retain their dependencies when copied into nested example groups. Memoized fixture blocks propagate dependencies to their consuming example. Scalar values such as symbols therefore keep their producer relationship even without an object identity. Shared fixture macros that assign and read values through reflection protect their producer initialization and require the full environment when that producer changes.

External Ruby module fields are traced during active tests. Executed lines distinguish external assignments from unexecuted branches, while ambiguous statements remain conservative. Runtime instruction loading is treated as loading rather than application data flow. Recorded readers connect to recorded writes regardless of their observed order, because PR execution can use a different seed or file distribution. Boot coverage protects application code used during initialization. Direct dynamic loading and application methods executed during `require` require broader execution. Extra module field tracing stays outside collector infrastructure and unobserved library setup. Previously observed cache writes remain relevant during later library loading.

Ruby support files under spec directories are sources unless they are runnable spec files. Their method calls and code evaluated during loading retain dependency and initialization protection.

Native calls from owned source and test code remain uncertain unless the collector models their effects. Default VM definition callbacks, ordinary loading, known accessors and mutations of tracked builtin containers keep their existing semantics. A tracked hash read with a fixed symbol key and standard default behavior retains its field dependencies. Lookups with a default procedure or an unknown key remain uncertain. Method compatibility also preserves literal types. This protects unknown receiver lookups and process state such as random seeds without depending on a list of mutator names.

The collector records boot coverage and source structure. A PR can reuse a method body mapping only when the declaration and protected boot code still match. Method digests retain their starting lines and body content. Source compatibility also retains each method body's starting and ending line. Adding or removing a line inside a method therefore invalidates compatibility and runs the complete affected environment. For example, a blank line in an unused method can change a later constant computed with `__LINE__`, `Method#source_location`, `Binding#source_location` or `caller_locations`. Its earlier reader method can remain unchanged. Literal edits that preserve line boundaries can still use method mappings when their dependency structure matches. These structural checks supplement execution tracing.

Published mappings store source names once and encode their dependency sets as numeric references or bitmaps. The producer merges one raw process mapping at a time. The planner follows the recorded callers without rebuilding every graph edge. Large raw process mappings stay in the job workspace and are excluded from uploaded selection evidence.

Regular backend collection runs at most 40 files per Ruby process and reuses the configured database slots only after each process exits. Every batch has a distinct process identity in the execution manifest. The multisite process retains the complete file inventory. Required main runs and PR execution keep their existing file distribution.

Each process writes its mapping and execution record. Publication verifies that every required process role completed with the expected files, revision and environment. In particular, a missing multisite report cannot be hidden by a regular process that loaded the same files.

Frontend and Vitest environments currently use a conservative strategy. Changed test files protect their owning environment, and application changes without a recorded dependency graph also run the relevant full inventory. Browser file loaders record registrations and execution so an unselected file cannot silently register tests during bundle loading.

## Artifact reuse

The preparatory job downloads the latest available mapping bundle from a successful completed main push in the mapping producer workflow and matching repository. It validates the producer revision and archive entries. Downloads allow at most 200 MB per ZIP archive and 500 MB per extracted mapping. The extracted limit accommodates combined core graphs, whose captured partial workload exceeds 275 MB while compressing to 12 MB. Failed or unavailable collection leaves selection conservative. No new credential is required. The download uses the workflow's existing `GITHUB_TOKEN` with read permissions.

Official plugin and theme revisions are recorded in the catalog. Consumer jobs pin those revisions, discover their current inventory again and verify the planned environment before execution. Lockfiles, commands, the collection and runner implementation, and relevant external revisions contribute to the environment identity. A collector upgrade invalidates an older mapping. Ordinary application commits retain the same runtime identity.

The producer calls the existing backend and migration workflows with explicit collection inputs. Their plan artifacts have distinct names. Both bundles must come from the same completed successful producer before the freshness gate skips collection. System and frontend environments retain conservative application selection without running an extra traced suite. The producer does not cancel an active collection when later commits land.

## Audit and rollout

`TEST_SELECTION_MODE` defaults to `audit`. Audit runs the full reference inventory and then the candidate selection. Reports show the candidate files, actual files and failures found by the reference but absent from the candidate. A direct attempt to execute an audit candidate as a skipping plan is rejected. When the candidate assignment equals the full reference, the runner validates its metadata and reuses the reference report. It records that reuse and executes the files once. A strict subset still runs separately. Audit jobs have twice their ordinary time budget to accommodate both runs. Required main jobs retain their original budgets.

After validating the recorded scenarios and representative PRs, maintainers can set `TEST_SELECTION_MODE=select`. `TEST_SELECTION_AUDIT_PERCENT` defaults to `10`, so a deterministic sample of PR revisions continues to receive full comparisons. `TEST_SELECTION_MODE=full` disables skipping. Main remains full in every mode.

Reports are published as `test-selection-*` and `migration-test-selection` artifacts. They distinguish assigned, loaded and executed files, missing or unassigned files, missing process roles and failed examples. A mismatch fails the job rather than expanding its selection. Failure lists contain executed examples, so framework fixtures that construct fake failures do not count as regressions.

Turbo retries preserve the plan's seed. Execution reports retain failed attempts while accepting a successful retry that respects the assignment.

A finite replay cannot prove every future Ruby program safe. Full main runs and audit comparisons remain necessary to detect dependency gaps and interactions. An observed missed regression blocks rollout, including a passing new spec that changes shared state and breaks an existing reader. The candidate must retain that reader before the gap can be considered resolved.

Cache provenance identifies the producing Ruby method as well as the shared field. Coverage still records test dependencies by source file. Structurally compatible source checks compare method body digests and seed the changed methods into the field graph. Collection and planning share definition ordering. Definition changes, unsupported generated code and ambiguous evidence require broader execution.

## Replaying changes locally

Run `bundle exec ruby script/ci/test_selection_lab/run.rb /absolute/disposable/path` from a committed checkout in the existing test environment. The destination must not exist and must be outside the checkout. The harness creates an independent Git repository, verifies that its tracked tree exactly matches the source and retains it for inspection. It shares installed dependencies and disposable test databases with the supplied environment, so serialize it with other test commands.

The initial campaign uses six real core spec files. It collects a baseline and creates separate Git commits for a new spec, a successful Turbo retry, changed spec, documentation, a broken URL helper, a new application file, shared configuration, deletion, rename, class autoload deletion and rename, and a rename combined with the helper change. Expected file sets are specified before selection. Each case executes the candidate and a full reference over that declared inventory, checks exact file execution and compares failures. A failed expectation stops the campaign. The disposable checkout supplies its own Gemfile so repository gems resolve from that snapshot. Additional scenarios pass a producer's scalar value through context hooks, helper methods and memoized fixtures. Four can be mapped precisely, including a compact declaration on one line. They require the writer and reader, omit an unrelated spec, and compare the actual reader failure against the full reference. Three use an eager fixture, a shared fixture macro and an alias of that macro. They verify full execution for the resulting uncertainty about initialization. The final scenario starts a background task in one spec and lets it execute during another. A reference run exposes the regression that running the reader alone would miss. The reflective macro probes use the installed fixture implementation with its adapter that omits database transactions. They do not verify database behavior. This bounded campaign does not stand in for the separate browser, plugin, theme and migration evidence.

### Unobserved effects

An executed call graph does not cover branches that the baseline never entered.
If a producer feeds a caller with conditional control flow, iteration, exception
handling, or early exits, its possible effects remain uncertain. Changes to those
inputs select the full environment. Literal `if false` branches are excluded from
this uncertainty because their condition cannot depend on a changed producer.

When an application or external Ruby method has uncertain effects, collection stops detailed value tracking inside that call. It records nested application sources as uncertain instead. For example, changing a producer called inside an unchanged conditional cache writer selects the full environment. That protects dependencies whose detailed value flow was omitted and avoids tracking every internal operation of a complex library call.

When an uncertain external call wraps an RSpec example, collection temporarily resumes detailed tracking for the example block and restores coarse tracking when that block returns. Hook work can remain coarse without treating the example body as shared initialization.

Native call callbacks remain enabled throughout external value loops. A name such as `length` can identify an application accessor, and `[]` can invoke a `Method` object. Neither name alone establishes builtin behavior. For example, one spec can populate an application `attr_accessor`, another can copy its scalar through an external loop, and a third can consume that copy. The getter has no Ruby body for line coverage to observe. Replays cover direct accessors and native methods created in a spec or an external helper.

Repeated receiver observations are cached within each test file. Recording new object dependencies invalidates that receiver's cached observation. External method and block events retain their dependencies without disabling native calls. Native callbacks use a handler for each tracking mode, selected inside the collector callback before application execution resumes.

For example, changing a producer from `:original` to `:broken` can activate an
unchanged `if Producer.value == :broken` cache write. Running only the writer
would pass while a later reader fails. The lab compares both executions and
requires the reader to remain selected.

Process environment writes also protect their producers conservatively. `ENV`
is shared process state, so a writer and reader in separate spec files cannot be
isolated using only the writer's observed calls.

Input dependent lookups and reflective calls have the same uncertainty. For
example, `writers.fetch(Producer.value).write(value)` can choose a receiver that
the baseline never invoked. A fixed list of observed callees cannot justify
omitting its readers.

The audit distinguishes example failures from an incomplete comparison. Its
artifact records reference and candidate success, known failures outside
examples, unreported process failures, and whether the comparison completed.
An empty `missed_failures` array alone does not mean the candidate was safe.

The native lookup replay changes an array index from 0 to 1, redirecting a write into a shared cache. The random state replays change a seed from 1234 to 5678, with the producer defined in application code or a spec helper. The loading replay changes a helper from 3 to 4 and recomputes a constant before tests run. Every replay preserves the reader failure found by its full reference.

External Ruby API calls retain their possible argument sources while native operations run inside them. The runtime call signature covers ordinary and block defined methods. Unavailable generated source remains uncertain, and code installed under plugin gem directories receives the same treatment as other external code. Replays cover application callers and direct spec callers.

Arguments remain possible inputs when a callee mutates a tracked field or container. A framework callback with an unmodeled body also protects its caller inputs. The matcher replay passes a producer value into a custom matcher that changes random state, requiring the otherwise indirect reader to stay selected.

`spec/tasks/test_selection_scenarios_spec.rb` runs the shared state Git replays in normal CI. Execution validation separately checks required skipped specs, loaded files without examples and compilation without execution. The tracker observes the first executed line in a newly compiled spec, rather than tracing every application line. Loaded features and registered example metadata cover cached requires. Empty scripts are recorded directly because they provide no line hook. Loading checks cover owned test paths and inventoried symlink targets. Registered examples outside that set still count as unassigned tests. Temporary fixture code outside the inventory does not become a runnable test solely because its filename ends in `_spec.rb`.
