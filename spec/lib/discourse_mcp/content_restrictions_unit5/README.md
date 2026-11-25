**Unit 5: core tag and category guard oracle**

Baseline: `afe9215fe56bb761309732ca0bd1087155a335d3`. The implementation is intentionally absent. All examples carry `[cr-u5]` and use real records plus core model, service, controller, or scheduled-job entry points. No MCP tool is used. Request specs explicitly use `type: :request` because they live under this oracle directory.

Final baseline result: **65 examples: 41 observed RED, 24 expected GREEN and observed GREEN**. Every RED is an RSpec assertion failure, with no fixture/setup exception, pending example, or error outside examples. Seed **57019**. The complete run receipt, command, source hashes, exception messages and per-example classifications are in [verification.json](verification.json). `bin/lint --fix --verbose` passed for all nine new Ruby files in its run (RuboCop plus Syntax Tree); the final added depth cases also passed follow-up lint in `t92`.

**Grounding**

Read the current `Tag`, `TagsController`, `DiscourseTagging.add_or_create_synonyms`, `Jobs::CleanUpTags`, `Tag.unused`, `Category`, `CategoriesController`, `CategoryUpdater`, `CategoryDestroyer`, and their relevant existing model/request/service/job specs. No `Categories::Update` service is present; the controller calls `CategoryUpdater.update`.

The rule setup uses `McpContentRule.create!` with `rule_kind: "forum_content"` and the current `ForumContentRule::CONFIG_CONTRACT`: `allow` has `mode`, `category_ids`, `tag_ids`; `deny` has `category_ids`, `tag_ids`. Each allow-reference case uses selected mode. No proposed implementation class, callback name, helper, or translation key is assumed. The only shared helper creates real rule rows and checks observable error wording. Guards must work for a human administrator independently of an MCP request.

Fixed fixtures use the new range **113_570_000..113_579_999**. A numeric-literal scan of all 49 Ruby/JSON files in units 1–4, including ignored files through filesystem traversal, found no literal in the checked 113_560_000..113_579_999 range. Unit 2's generated fixture offsets were also read: its fixed records use 91 million, generated topic/post records 92/93 million, and related records 94 million. Other records here use normal fabricator-generated IDs.

**Decisions**

- Both allow and deny references protect tag/category identity. Allow cases use selected mode; no allow-only deletion exemption is permitted.
- A denied descendant cannot escape by moving to an unrelated root or detaching to the top level. Cover immediate children, grandchildren, and non-leaf branches; a failed update also preserves the simultaneous name edit.
- Existing grandchildren remain protected for both moves and deletion after `max_category_nesting` is lowered from 3 to 2. Subtree guard coverage must not be capped by the current creation limit.
- Moving into a denied subtree or out of an allowed subtree stays allowed because access only shrinks. Moving into an allowed subtree stays allowed as the plan's explicit human-admin access expansion.
- Moving within the same denied subtree, or moving a directly denied root with its descendants intact, stays allowed: the denied ID and its coverage remain unchanged. A rename is allowed for the same reason.
- An unreferenced descendant of an allowed root may be deleted; only the directly referenced allow category is protected. Deleting that descendant only shrinks selected access.
- Tag synonym conversion is tested through both the endpoint and the actual bulk service, by existing ID and a case-insensitive existing name. The protected source must retain its own ID/target state and topic tags. Adding an unreferenced synonym to a protected target stays allowed.
- Destroying a canonical tag must also preserve any referenced synonym reached through dependent destruction. The no-rule cascade remains available.
- Tag deletion must raise an explanatory exception through an outer transaction; the test observes propagation, surviving topic/group associations, and absence of a continuation marker, without naming a new exception class. Category model mutations instead return false with model errors, preserving dependent timers even in an outer transaction.
- Category API failures use the existing **422 + errors** JSON contract. Tag delete accepts an explanatory **4xx + errors** response; synonyms retain the existing **200 + failed/failed_tags** contract. The error must explain a content rule/restriction, without fixing a new translation key or exact message.
- Unused-tag selection, preview, admin deletion and scheduled cleanup must omit protected tags while still deleting an unreferenced unused peer. Cleanup is selective, not a blanket refusal.

**Checks against weaker implementations**

These are distinguishing fixtures and assertions, not claims of production mutation runs (production edits were prohibited): deny-only protection fails the allow cases; controller-only protection fails direct model/service cases; a swallowed callback fails the outer-transaction propagation and continuation marker; destruction after dependent callbacks fails association/timer preservation; identity checks confined to model saves miss the real synonym bulk SQL; ID-only synonym checks fail uppercase-name inputs; a cleanup destroy guard without selection filtering fails peer cleanup/preview; immediate-parent checks fail grandchildren; depth-capped subtree queries fail the move/delete cases after the nesting limit is lowered; direct-reference-only category checks fail denied descendants; and blanket active-rule or reparent bans fail the active-rule/no-rule controls. All 41 required guards were observed failing on the unmodified baseline.

**Needs non-test gate**

No requested behavioral guard is deferred. These single-connection response/state specs do not establish concurrency safety between rule edits and target mutations; implementation review must check their synchronization. They also cannot certify every plugin or raw-SQL callback bypass (`delete_all`/`update_all`); the named synonym bulk path is exercised, while a broader bypass audit belongs to implementation review. Human-facing rendering/localization of the explanatory errors and the deliberate admin restriction notice belongs to the unit 6 UI gate.

**Plan fault**

The plan's claim that a category `errors.add` plus `throw :abort` will already report through the category path is incomplete for deletion. The current `CategoriesController#destroy` calls `CategoryDestroyer.destroy`, which uses `category.destroy!`; `ApplicationController` rescues `RecordInvalid` and `Discourse::InvalidParameters`, but has no `RecordNotDestroyed` handler. A destroy callback abort alone can therefore become an unhandled exception. The deletion request oracle requires an explanatory 422 `errors` response as well as surviving category/definition records. Implementing that observable contract needs error adaptation in addition to the model guard. Update already goes through `CategoryUpdater` and `json_result`.

**Test inventory**

Each row below is the exact final RSpec example name. RED signatures were checked against each complete exception message, then the inventory was checked again against the receipt and source declarations. GREEN controls are deliberately expected GREEN at baseline.

| File | Example name | Baseline result and reason/signature |
| --- | --- | --- |
| [category_model_spec.rb](category_model_spec.rb) | `Category#destroy [cr-u5] destroys a category and its dependent timer inside an outer transaction with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [category_model_spec.rb](category_model_spec.rb) | `Category#destroy [cr-u5] preserves a denied grandchild and its definition inside an outer destroy transaction` | RED — CATEGORY OUTER DELETE: denied grandchild destroyed; destroy returns the destroyed record instead of false, timer deleted and definition soft-deleted |
| [category_model_spec.rb](category_model_spec.rb) | `Category#destroy [cr-u5] returns model errors when directly destroying the allow-referenced category` | RED — CATEGORY MODEL DELETE: referenced category destroyed; destroy returns the destroyed record instead of false, timer deleted and definition soft-deleted |
| [category_model_spec.rb](category_model_spec.rb) | `Category#destroy [cr-u5] returns model errors when directly destroying the deny-referenced category` | RED — CATEGORY MODEL DELETE: referenced category destroyed; destroy returns the destroyed record instead of false, timer deleted and definition soft-deleted |
| [category_model_spec.rb](category_model_spec.rb) | `Category#update [cr-u5] returns model errors when directly detaching a denied grandchild` | RED — CATEGORY MODEL MOVE: denied grandchild escaped; true instead of false, parent detached and model errors empty |
| [category_model_spec.rb](category_model_spec.rb) | `CategoryUpdater.update [cr-u5] lets the updater move a branch with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [category_model_spec.rb](category_model_spec.rb) | `CategoryUpdater.update [cr-u5] returns category errors from the real updater when moving a denied branch outside` | RED — CATEGORY UPDATER: denied branch escaped; true instead of false, parent changed and model errors empty |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] lets an admin delete a category and soft-delete its definition with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] lets an admin delete an unreferenced category while another category is denied` | expected GREEN at baseline; observed GREEN — The rule references another record; unreferenced deletion stays available. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] lets an admin delete an unreferenced descendant of an allowed category` | expected GREEN at baseline; observed GREEN — Only direct allow references protect deletion; deleting this unreferenced descendant shrinks selected access. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] refuses deleting an existing denied grandchild after the nesting limit is lowered` | RED — CATEGORY DELETE: denied descendant disappeared; HTTP 200, grandchild deleted and definition soft-deleted after max_category_nesting was lowered to 2 |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] reports category errors when an admin deletes a child inside a denied subtree` | RED — CATEGORY DELETE: denied descendant disappeared; HTTP 200, descendant deleted and definition topic soft-deleted |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] reports category errors when an admin deletes a directly allow-referenced category` | RED — CATEGORY DELETE: referenced category disappeared; HTTP 200, category deleted and definition topic/post soft-deleted |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] reports category errors when an admin deletes a directly deny-referenced category` | RED — CATEGORY DELETE: referenced category disappeared; HTTP 200, category deleted and definition topic/post soft-deleted |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#destroy [cr-u5] reports category errors when an admin deletes a grandchild inside a denied subtree` | RED — CATEGORY DELETE: denied descendant disappeared; HTTP 200, descendant deleted and definition topic soft-deleted |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] lets an admin move a category into a denied subtree` | expected GREEN at baseline; observed GREEN — The move only shrinks access and is explicitly permitted by the plan. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] lets an admin move a category into an allowed subtree` | expected GREEN at baseline; observed GREEN — The plan explicitly permits a human admin to grow access by moving into an allowed subtree. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] lets an admin move a category out of an allowed subtree` | expected GREEN at baseline; observed GREEN — The move only shrinks access and is explicitly permitted by the plan. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] lets an admin move a denied category within the same denied subtree` | expected GREEN at baseline; observed GREEN — The category remains a descendant of the same denied root, preserving coverage. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] lets an admin move a directly denied root with its subtree intact` | expected GREEN at baseline; observed GREEN — Moving the denied root keeps its own ID and every descendant covered. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] lets an admin rename a category inside a denied subtree` | expected GREEN at baseline; observed GREEN — An ordinary rename keeps category IDs and subtree coverage unchanged. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] lets an admin reparent and detach categories with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] refuses moving an existing denied grandchild after the nesting limit is lowered` | RED — CATEGORY MOVE: denied subtree escaped; HTTP 200, parent moved outside after max_category_nesting was lowered to 2 |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] reports category errors when an admin moves a denied branch to outside` | RED — CATEGORY MOVE: denied subtree escaped; HTTP 200 instead of 422, parent and name changed |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] reports category errors when an admin moves a denied branch to top_level` | RED — CATEGORY MOVE: denied subtree escaped; HTTP 200 instead of 422, parent and name changed |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] reports category errors when an admin moves a denied child to outside` | RED — CATEGORY MOVE: denied subtree escaped; HTTP 200 instead of 422, parent and name changed |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] reports category errors when an admin moves a denied child to top_level` | RED — CATEGORY MOVE: denied subtree escaped; HTTP 200 instead of 422, parent and name changed |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] reports category errors when an admin moves a denied grandchild to outside` | RED — CATEGORY MOVE: denied subtree escaped; HTTP 200 instead of 422, parent and name changed |
| [category_requests_spec.rb](category_requests_spec.rb) | `CategoriesController#update [cr-u5] reports category errors when an admin moves a denied grandchild to top_level` | RED — CATEGORY MOVE: denied subtree escaped; HTTP 200 instead of 422, parent and name changed |
| [tag_cleanup_spec.rb](tag_cleanup_spec.rb) | `Jobs::CleanUpTags#execute [cr-u5] deletes both old unused tags through the scheduled job with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_cleanup_spec.rb](tag_cleanup_spec.rb) | `Jobs::CleanUpTags#execute [cr-u5] keeps a topicless allow-referenced tag while the scheduled job deletes an unused peer` | RED — CLEANUP JOB: referenced tag was deleted or unreferenced cleanup was blocked; surviving fixture IDs are [] |
| [tag_cleanup_spec.rb](tag_cleanup_spec.rb) | `Jobs::CleanUpTags#execute [cr-u5] keeps a topicless deny-referenced tag while the scheduled job deletes an unused peer` | RED — CLEANUP JOB: referenced tag was deleted or unreferenced cleanup was blocked; surviving fixture IDs are [] |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] destroys an unreferenced tag while another tag is protected` | expected GREEN at baseline; observed GREEN — The rule references another record; unreferenced deletion stays available. |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] destroys tags and their synonyms inside an outer transaction with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] preserves the allow-referenced synonym when its canonical tag is destroyed` | RED — expected StandardError but nothing was raised; actual collection contained: []; canonical tag and protected synonym deleted |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] preserves the deny-referenced synonym when its canonical tag is destroyed` | RED — expected StandardError but nothing was raised; actual collection contained: []; canonical tag and protected synonym deleted |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] propagates the allow-referenced tag destroy failure through an outer transaction` | RED — expected StandardError but nothing was raised; OUTER TRANSACTION: referenced tag disappeared; continuation marker persisted and topic tag removed |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] propagates the deny-referenced tag destroy failure through an outer transaction` | RED — expected StandardError but nothing was raised; OUTER TRANSACTION: referenced tag disappeared; continuation marker persisted and topic tag removed |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] raises with a rule explanation when directly destroying the allow-referenced tag` | RED — expected StandardError but nothing was raised; TAG DESTROY: referenced tag disappeared; topic/group associations removed |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag#destroy [cr-u5] raises with a rule explanation when directly destroying the deny-referenced tag` | RED — expected StandardError but nothing was raised; TAG DESTROY: referenced tag disappeared; topic/group associations removed |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag.unused [cr-u5] excludes a topicless allow-referenced tag while retaining unreferenced unused tags` | RED — UNUSED SCOPE: referenced tag remains eligible for cleanup; both fixture IDs remain eligible |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag.unused [cr-u5] excludes a topicless deny-referenced tag while retaining unreferenced unused tags` | RED — UNUSED SCOPE: referenced tag remains eligible for cleanup; both fixture IDs remain eligible |
| [tag_model_spec.rb](tag_model_spec.rb) | `Tag.unused [cr-u5] includes both topicless tags in unused with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#create_synonyms [cr-u5] lets an admin add an unreferenced synonym to a protected target` | expected GREEN at baseline; observed GREEN — The unreferenced source may become a synonym; the protected target retains its own ID. |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#create_synonyms [cr-u5] lets an admin convert a tag to a synonym with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#create_synonyms [cr-u5] reports a failed tag for an admin converting the allow-referenced synonym by id` | RED — ADMIN SYNONYM: referenced tag conversion succeeded; failed/failed_tags absent, target_tag_id and topic tags changed |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#create_synonyms [cr-u5] reports a failed tag for an admin converting the allow-referenced synonym by name` | RED — ADMIN SYNONYM: referenced tag conversion succeeded; failed/failed_tags absent, target_tag_id and topic tags changed |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#create_synonyms [cr-u5] reports a failed tag for an admin converting the deny-referenced synonym by id` | RED — ADMIN SYNONYM: referenced tag conversion succeeded; failed/failed_tags absent, target_tag_id and topic tags changed |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#create_synonyms [cr-u5] reports a failed tag for an admin converting the deny-referenced synonym by name` | RED — ADMIN SYNONYM: referenced tag conversion succeeded; failed/failed_tags absent, target_tag_id and topic tags changed |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#destroy [cr-u5] lets an admin delete a tag with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#destroy [cr-u5] lets an admin delete an unreferenced tag while another tag is protected` | expected GREEN at baseline; observed GREEN — The rule references another record; unreferenced deletion stays available. |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#destroy [cr-u5] reports a content rule error to an admin deleting the allow-referenced tag` | RED — ADMIN TAG DELETE: returned success; HTTP 200 instead of 4xx, referenced tag and topic association deleted |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#destroy [cr-u5] reports a content rule error to an admin deleting the deny-referenced tag` | RED — ADMIN TAG DELETE: returned success; HTTP 200 instead of 4xx, referenced tag and topic association deleted |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#destroy_unused [cr-u5] keeps a topicless allow-referenced tag while admin cleanup deletes an unused peer` | RED — ADMIN CLEANUP: referenced tag was deleted or unreferenced cleanup was blocked; surviving fixture IDs are [] |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#destroy_unused [cr-u5] keeps a topicless deny-referenced tag while admin cleanup deletes an unused peer` | RED — ADMIN CLEANUP: referenced tag was deleted or unreferenced cleanup was blocked; surviving fixture IDs are [] |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#destroy_unused [cr-u5] lets admin cleanup delete both unused tags with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#list_unused [cr-u5] omits the allow-referenced tag from the admin unused-tag preview` | RED — UNUSED PREVIEW: referenced tag is offered for deletion; preview includes both fixture names |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#list_unused [cr-u5] omits the deny-referenced tag from the admin unused-tag preview` | RED — UNUSED PREVIEW: referenced tag is offered for deletion; preview includes both fixture names |
| [tag_requests_spec.rb](tag_requests_spec.rb) | `TagsController#list_unused [cr-u5] previews both unused tags with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_synonyms_spec.rb](tag_synonyms_spec.rb) | `DiscourseTagging.add_or_create_synonyms [cr-u5] converts a tag and transfers its topic tags with no rules` | expected GREEN at baseline; observed GREEN — No McpContentRule rows: preserves the existing core mutation, preview, or cleanup behavior. |
| [tag_synonyms_spec.rb](tag_synonyms_spec.rb) | `DiscourseTagging.add_or_create_synonyms [cr-u5] permits an unreferenced tag to become a synonym of a referenced target` | expected GREEN at baseline; observed GREEN — The unreferenced source may become a synonym; the protected target retains its own ID. |
| [tag_synonyms_spec.rb](tag_synonyms_spec.rb) | `DiscourseTagging.add_or_create_synonyms [cr-u5] refuses conversion of the allow-referenced tag to a synonym by id` | RED — SYNONYM SERVICE: referenced tag conversion succeeded; true instead of failed-tag Hash, target_tag_id and topic tags changed |
| [tag_synonyms_spec.rb](tag_synonyms_spec.rb) | `DiscourseTagging.add_or_create_synonyms [cr-u5] refuses conversion of the allow-referenced tag to a synonym by name` | RED — SYNONYM SERVICE: referenced tag conversion succeeded; true instead of failed-tag Hash, target_tag_id and topic tags changed |
| [tag_synonyms_spec.rb](tag_synonyms_spec.rb) | `DiscourseTagging.add_or_create_synonyms [cr-u5] refuses conversion of the deny-referenced tag to a synonym by id` | RED — SYNONYM SERVICE: referenced tag conversion succeeded; true instead of failed-tag Hash, target_tag_id and topic tags changed |
| [tag_synonyms_spec.rb](tag_synonyms_spec.rb) | `DiscourseTagging.add_or_create_synonyms [cr-u5] refuses conversion of the deny-referenced tag to a synonym by name` | RED — SYNONYM SERVICE: referenced tag conversion succeeded; true instead of failed-tag Hash, target_tag_id and topic tags changed |

**Run unit 5 independently**

```sh
PATH=/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin:$PATH \
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit5/ --seed 57019
```

Only the authorized test database was used. No production implementation, configuration, migration, or existing spec was changed; no git mutation or service management was performed.

## Unit 5 review round 2 at `85c7e890132`

This section records the accepted findings from `9b5114149e3..85c7e890132`
and supersedes the earlier concurrency deferral for the specific schedules below.
Production code remains untouched. The new [review2_spec.rb](review2_spec.rb)
has **20 examples: 12 observed RED and eight observed GREEN controls**.
All examples carry `[cr-u5]`. Seed **57219**, combined with unit 2 enrichment:
**22 examples, 12 failures, zero pending, zero errors outside examples**.
All 12 failures are RSpec expectation failures for the accepted defects;
there are no fixture, connection, timeout, or thread exceptions.

### Grounding and observable contracts

Read Tag (including target_tag_validator and its validation condition), Category
(callback order, deletion, definition and event paths), McpContentRule,
DiscourseTagging.add_or_create_synonyms, site:import_structure, all existing unit 5
specs, and support.rb. The bulk synonym service has a listed-tag guard at this
HEAD; the plain model validator checks only existing synonyms and synonym targets.
The site structure importer resolves target_tag and calls tag.update!(t), so
plain update/update! need their own validation coverage.

Finding 1 exercises both update and update!, both selected allow and deny lists,
with a real persisted forum_content rule. A failed update must explain the
content-rule restriction and leave persisted target_tag_id nil. The bang form
must raise the ordinary ActiveRecord validation exception. Controls preserve
unlisted-source conversion to a listed target, and conversion with no rule rows,
through each public entry point.

Finding 3 is pinned rather than deferred. Each race disables transactional
fixtures, commits its target setup, and uses two real database connections with
distinct PostgreSQL backend PIDs. The main connection performs a real destroy!
inside an open transaction before starting the rule save on the second
connection. That connection explicitly confirms the target is still visible:
a plain existence check before saving is therefore insufficient.

There are two commit-release schedules for each target kind and list side:
rule_first waits for the rule transaction to commit before releasing the destroy;
destroy_first pauses after save, commits the destroy, then releases the rule
commit. If synchronization makes the save wait, the main connection releases the
destroy only after PostgreSQL reports the worker blocked by that connection.
The observable outcome pinned for this destroy-starts-first interleaving is a
successful destroy, a false rule.save with model errors, and no persisted rule.
The names describe the attempted commit-release schedule; a correctly blocked
rule save necessarily finishes after the destroy instead. No proposed production
class, constant, helper, or lock name is assumed.

Queues provide the latches; PostgreSQL lock observation decides when a blocked
save may proceed. There is no elapsed-time assumption of safety. Five/ten-second
deadlines fail loudly instead of hanging. Ensure blocks release/join the worker,
remove only the rule created by the example, and clean up any surviving fixture.
Category fixtures skip definition topics and use the seeded system user.

New fixed IDs are **113_577_001, 113_577_002, 113_578_001..113_578_004**,
within the reserved unit 5 range. An ignored-file-inclusive numeric scan and
source read confirmed none was already used by the existing unit 5 specs.

### New example names, observed RED signatures, and controls

The rows below are the full RSpec names from the seed-57219 receipt, checked
against the source declarations. Each race reached the public-state assertions;
none failed at its latch or database-connection preconditions.

| New example name | Observed result/signature |
| --- | --- |
| `Tag#update / #update! [cr-u5] rejects update converting the allow-listed tag to a synonym` | RED: PLAIN SYNONYM UPDATE: listed tag conversion succeeded (true instead of false); content-rule explanation empty; persisted target_tag_id was 113577002 instead of nil. |
| `Tag#update / #update! [cr-u5] rejects update converting the deny-listed tag to a synonym` | RED: PLAIN SYNONYM UPDATE: listed tag conversion succeeded (true instead of false); content-rule explanation empty; persisted target_tag_id was 113577002 instead of nil. |
| `Tag#update / #update! [cr-u5] permits update converting an unlisted tag to a listed target` | GREEN control: returns true; unlisted source becomes a synonym of the listed target (113577002). |
| `Tag#update / #update! [cr-u5] preserves update synonym conversion with no rule rows` | GREEN control: returns true; persisted target_tag_id is 113577002 with zero rule rows. |
| `Tag#update / #update! [cr-u5] rejects update! converting the allow-listed tag to a synonym` | RED: expected ActiveRecord::RecordInvalid but nothing was raised; content-rule explanation empty; persisted target_tag_id was 113577002 instead of nil. |
| `Tag#update / #update! [cr-u5] rejects update! converting the deny-listed tag to a synonym` | RED: expected ActiveRecord::RecordInvalid but nothing was raised; content-rule explanation empty; persisted target_tag_id was 113577002 instead of nil. |
| `Tag#update / #update! [cr-u5] permits update! converting an unlisted tag to a listed target` | GREEN control: returns true; unlisted source becomes a synonym of the listed target (113577002). |
| `Tag#update / #update! [cr-u5] preserves update! synonym conversion with no rule rows` | GREEN control: returns true; persisted target_tag_id is 113577002 with zero rule rows. |
| `McpContentRule#save during target destruction [cr-u5] saves the deny rule while its listed category survives` | GREEN control: real forum_content rule and listed target both persist. |
| `McpContentRule#save during target destruction [cr-u5] refuses the deny rule racing category destruction with rule_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |
| `McpContentRule#save during target destruction [cr-u5] refuses the deny rule racing category destruction with destroy_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |
| `McpContentRule#save during target destruction [cr-u5] saves the allow rule while its listed tag survives` | GREEN control: real forum_content rule and listed target both persist. |
| `McpContentRule#save during target destruction [cr-u5] refuses the allow rule racing tag destruction with rule_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |
| `McpContentRule#save during target destruction [cr-u5] refuses the allow rule racing tag destruction with destroy_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |
| `McpContentRule#save during target destruction [cr-u5] saves the deny rule while its listed tag survives` | GREEN control: real forum_content rule and listed target both persist. |
| `McpContentRule#save during target destruction [cr-u5] refuses the deny rule racing tag destruction with rule_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |
| `McpContentRule#save during target destruction [cr-u5] refuses the deny rule racing tag destruction with destroy_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |
| `McpContentRule#save during target destruction [cr-u5] saves the allow rule while its listed category survives` | GREEN control: real forum_content rule and listed target both persist. |
| `McpContentRule#save during target destruction [cr-u5] refuses the allow rule racing category destruction with rule_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |
| `McpContentRule#save during target destruction [cr-u5] refuses the allow rule racing category destruction with destroy_first commit release` | RED: RULE/DESTROY RACE: both target destroy and referencing rule save committed; save returned true, rule persisted, errors empty. Target visibility before save and target absence after commit both passed. |

### Checks against weaker implementations

The HEAD service-only synonym guard is an actual weaker implementation and all
four plain-update examples fail against it. Allow-list cases distinguish a
deny-only guard. The unlisted-source/listed-target controls distinguish a guard
that blocks every conversion while any rule exists, or guards the target rather
than the source. No-rule controls preserve the existing model behavior.

For every race, the second connection sees the target before saving even though
the first connection has already deleted it in an uncommitted transaction. Thus
an unsynchronized target-existence validation would still admit the rule; both
commit-release schedules expose that weaker approach. Four surviving-target
controls (tag/category, allow/deny) reject a blanket ban on rule saves. These are
fixture/state checks and reasoning about weaker implementations; no production
mutation was made to simulate a fix, and no GREEN claim is made for the guards.

### Disposition of declined finding 2

Agree with the decline. Re-read generic_bulk.rb's category delta update and
Base#update_records: parent_category_id is passed into the delta batch, staged
through raw PG COPY, and applied with UPDATE ... FROM via @raw_connection.exec.
That path does not invoke Category model validations or callbacks. Treating an
operator-run bulk import as direct database authority is consistent with the
stated trust boundary. This is a documented limit, not a guard promised by these
specs. It does not excuse site:import_structure's ordinary tag.update! path,
which is explicitly covered above.

### Needs non-test gate

- No accepted finding is deferred for inability to build a reliable test. The
  race examples pin two specific destroy-starts-first schedules for directly
  listed tags/categories on both sides; they do not prove all interleavings.
  Implementation review must still check rule edits, rule-starts-first races,
  category subtree/reparent races, synonym races, and cross-process coordination.
- Bulk import delta updates and other operator raw SQL remain outside model-guard
  guarantees by the accepted trust boundary. Plugin callback bypasses need their
  own review; these tests do not certify them.
- Error wording/localization as rendered to administrators and the deliberate
  restriction notice remain the unit 6 UI gate. The synonym examples only assert
  the observable content-rule explanation through model errors/exceptions.

### Inventory refresh and run receipts

The unit 2 baseline run (seed 57219) observed **2 examples, 1 failure** with exactly
three stale category anchors, and no IndexError. Updated category_create
**638 → 644**, category_update **652 → 658**, and category_events **1230 → 1236**
after re-reading their bodies and the reviewed diff. Both enrichment examples
then passed in the combined run; all **245 live evidence occurrences** and graph
references were also checked directly after the refresh. Historical metadata is
retained; unit5_review2_refresh records this revision. See the
[unit 2 README](../content_restrictions_unit2/README.md).

Run commands use the repository Ruby **4.0.7**, Bundler **4.0.23**, LOAD_PLUGINS=1,
and only RAILS_DB=discourse_test_mcp_content through hc:

```sh
PATH=/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin:$PATH \
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit5/review2_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --seed 57219 --format documentation \
  --format json --out /tmp/cr-u5-review2-combined-57219.json
```

Raw receipts: `/tmp/cr-u5-review2-inventory-before.json` (inventory RED),
`/tmp/cr-u5-review2-red-57219.json` (initial regression run), and
`/tmp/cr-u5-review2-combined-57219.json` (final examples plus refreshed inventory).
The complete per-example result and signature inventory is preserved above, so
this record does not depend on temporary files surviving.

Final lint: `bin/lint --fix --verbose review2_spec.rb` passed RuboCop (one file,
zero offenses) and Syntax Tree. The command used the explicit installed Ruby,
Node and pnpm paths; initial attempts lacked the hc runtime paths, and the first
successful linter launch identified two describe-method naming offenses, which
were corrected before the passing run. bin/lint reports no configured core
linter for these Markdown/JSON paths; JSON parsing and git diff --check pass.

The final linted focused run with seed **57219** again produced **22 examples,
12 intentional failures**. The second-seed run mixed all existing unit 5 specs
with review2_spec.rb and unit 2 enrichment:

```sh
PATH=/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin:$PATH \
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit5/ \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --seed 57220 --format progress \
  --format json --out /tmp/cr-u5-review2-full-57220.json
```

Observed **87 examples, 12 failures, zero pending, zero errors outside examples**.
The exact same 12 new regression names failed for the same signatures; all eight
new controls, all **65 existing unit 5 examples**, and both enrichment examples
passed. No IndexError or concurrency timeout/fixture exception occurred. This
checks repeatability and cleanup under a different example order without claiming
coverage of every possible concurrency schedule. The complete live evidence and
graph-reference check was repeated after the refresh, with no mismatches.

Only the four authorized files changed. No production code, other spec,
migration, core database, git history/index/ref mutation, or service management was
part of this work; the new guards intentionally remain RED against HEAD.


## Unit 5 review round 3 at `6bb68077df8`

Accepted findings from `dbea3b5a59e..6bb68077df8` are pinned test-first in the
new `review3_spec.rb`, with **10 `[cr-u5]` examples, all observed RED**. No
production fix was made. The new fixture range **113_580_000..113_580_999** was
checked against all 60 pre-existing Ruby/JSON files in units 1–5, including
ignored files, before authoring; no numeric literal overlapped. Unit 2's
generated ID formulas were also read and use separate 90–94 million ranges.

### Stale config and rule-kind transitions

Four stale-instance cases cover tags/categories on allow/deny sides. A separate
instance removes the target from the persisted rule; the real target is then
destroyed. The original loaded instance retains that target and changes the
allow mode, ensuring it attempts an actual config write. Its save must return
false with errors and leave the persisted target list empty. This specifically
exposes comparison with the stale instance's old config: both the stale previous
and stale new configs list T, while the current database row does not.

Four further cases start with a non-forum row carrying a missing target, then
change only `rule_kind` to `forum_content`. This distinguishes newly entering
the guarded rule kind from editing an existing forum rule that already has a
legacy missing reference. Each save must be refused, retain the original kind,
and create no forum-content row. Tag/category and allow/deny coverage rejects
fixes checking only one model or side. These fixtures demonstrate the weaker
HEAD implementation failing; no production mutation was permitted by the scope.

### Deterministic category delete/reparent interleaving

Two cases use `CategoryDestroyer.destroy` and `CategoryUpdater.update` on two
real connections with distinct PostgreSQL backend PIDs, outside transactional
fixtures. One has no rules; the other has a valid `forum_content` row affecting
no target. Thus either operation is permitted in isolation.

The update thread loads its own category instance and waits at a queue latch.
A thread-scoped SQL notification observer pauses delete immediately after its
real `SELECT ... categories ... FOR UPDATE` finishes. It releases the updater,
then polls `pg_blocking_pids` until PostgreSQL confirms the update is waiting
on the delete connection. Only then does delete proceed. At HEAD this creates
the real row-lock/advisory-lock cycle, without a sleep or mocking either
service. The observer recognizes a SQL boundary, not a proposed lock helper.
A lock-order fix that acquires the common guard before the category row can
still reach this boundary; its updater may wait on that guard instead.

The final assertions explicitly reject `ActiveRecord::Deadlocked` from either
side, require delete to succeed, and require the category to be absent and its
new-parent candidate to survive. A serialized updater may return a boolean or
raise `ActiveRecord::RecordNotFound` after losing to delete. Other exceptions
are rejected. Queue/statement deadlines fail loudly; ensure blocks unsubscribe,
release/join the worker, remove the example's rule and clean up surviving rows.
The final with-rule run uses a forum rule, rather than the earlier PM-only
fixture. Both reproduce the same deadlock.

### Exact new inventory and observed RED signatures

All rows below are from the final post-lint seed-68321 run and refer to
`review3_spec.rb`.

| File | Full example name | Observed RED signature |
| --- | --- | --- |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses a stale allow config reintroducing a destroyed category` | `save` returned true, errors were empty, and persisted config contained `[113580001]` instead of `[]`; destroyed target remained absent. |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses a stale allow config reintroducing a destroyed tag` | `save` returned true, errors were empty, and persisted config contained `[113580001]` instead of `[]`; destroyed target remained absent. |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses a stale deny config reintroducing a destroyed category` | `save` returned true, errors were empty, and persisted config contained `[113580001]` instead of `[]`; destroyed target remained absent. |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses a stale deny config reintroducing a destroyed tag` | `save` returned true, errors were empty, and persisted config contained `[113580001]` instead of `[]`; destroyed target remained absent. |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses switching to forum_content with a missing allow category` | `update` returned true, errors were empty, rule kind became `forum_content` instead of `review3:old`, and a forum row existed. |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses switching to forum_content with a missing allow tag` | `update` returned true, errors were empty, rule kind became `forum_content` instead of `review3:old`, and a forum row existed. |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses switching to forum_content with a missing deny category` | `update` returned true, errors were empty, rule kind became `forum_content` instead of `review3:old`, and a forum row existed. |
| `review3_spec.rb` | `McpContentRule#save with obsolete target state [cr-u5] refuses switching to forum_content with a missing deny tag` | `update` returned true, errors were empty, rule kind became `forum_content` instead of `review3:old`, and a forum row existed. |
| `review3_spec.rb` | `CategoryDestroyer.destroy racing CategoryUpdater.update [cr-u5] completes delete racing reparent with rule rows without deadlock` | Captured updater `ActiveRecord::Deadlocked` / `PG::TRDeadlockDetected`; PostgreSQL reported a transaction ShareLock ↔ advisory ExclusiveLock cycle. Delete completed and removed the category. |
| `review3_spec.rb` | `CategoryDestroyer.destroy racing CategoryUpdater.update [cr-u5] completes delete racing reparent without rule rows without deadlock` | Captured updater `ActiveRecord::Deadlocked` / `PG::TRDeadlockDetected`; PostgreSQL reported a transaction ShareLock ↔ advisory ExclusiveLock cycle. Delete completed and removed the category. |

### Receipts, inventory and remaining gates

The focused seed-58319 run observed **10 examples, 10 assertion failures**,
including both actual deadlocks. The combined seed-68320 and final post-lint
seed-68321 runs each observed **129 examples, 42 expected failures**, zero
pending and zero errors outside examples: these 10 pins and all 32 unit 6
examples RED; all **85 pre-existing unit 5 examples** and both unit 2 inventory
examples GREEN. The final run repeats the deterministic interleaving with a
forum row, under a different example order. No latch timeout or setup exception
occurred. Raw receipts are `/tmp/cr-u5-review3-58319.json`,
`/tmp/cr-u6-combined-68320.json` and `/tmp/cr-u6-final-68321.json`.

Two direct comparisons found all **245 unit 2 exact-line anchors** current at
HEAD and all graph references valid. Its JSON needs no refresh. The standalone
inventory run, seed 58319, passed **2 examples, 0 failures**. See the
[unit 2 verification](../content_restrictions_unit2/README.md) and the
[unit 6 run command and inventory](../content_restrictions_unit6/README.md).

Final targeted `bin/lint --fix --verbose` passed RuboCop and Syntax Tree for
all five new Ruby files (one unit 5, four unit 6). Specs ran only through `hc`
with repo Ruby 4.0.7, Bundler 4, `LOAD_PLUGINS=1` and
`RAILS_DB=discourse_test_mcp_content`. No migration, core database operation,
service management or git history/index/ref change was performed.

Neither accepted finding is deferred as a non-test gate. These two race pins
prove a specific delete-row-lock-first interleaving, not every possible
schedule. Implementation review must still verify global lock ordering,
outer transactions, retry behavior and cross-process coordination. The
request/UI gates and the documented raw-SQL/bulk-import trust boundary remain
as recorded above. Concurrent frontend work belongs to the paired implementer
and was not edited by this oracle job.
