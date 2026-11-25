# Unit 6 server oracle

Baseline: **HEAD `6bb68077df8`**, reviewed against the 2026-11-25 handoff,
plan sections 5 and 10, and the explicit HTTP contract in this job. All examples
are request specs (`type: :request`) tagged in their names with **`[cr-u6]`**.
`support.rb` contains fixtures only. No proposed updater/controller/helper name
is part of the oracle: assertions observe HTTP responses, persisted
`McpContentRule` rows, and `UserHistory` staff actions.

Fixed fixture range: **114_600_000..114_609_999**. A filesystem traversal
(including ignored files) of all 60 pre-existing Ruby/JSON files in units 1–5
found no numeric literal in this range or the new unit 5 review-3 range
113_580_000..113_580_999. Unit 2's generated fixtures were also checked in
`canary_support.rb`: categories/tags use 91 million, topics/posts 92/93 million,
and related uploads 94 million. The harness's generated IDs use 90 million.
Actual unit 6 fixed IDs are categories 114_600_001..003 and 114_600_023, tags
114_600_011..012 and 114_600_021..022, and absent IDs 114_600_091..092/099.

## Fixture and impact design

The admin request registry uses the existing core-kind registration API and
14 deliberately different primitives, with database exposure choices set
explicitly. It includes `:none`, `:untouched`, `:enforced`, `:unenforced`,
undeclared and `:unbounded` declarations; a tool blocked only by forum rules;
a tool blocked only by PM rules; an exit-path tool; resources, a resource
template and a prompt; and disabled, emergency-blocked and unavailable tools.
The implementations raise if invoked. Requests never call them.

Exactly 11 primitives are exposed and available. No-rule catalog counts are
**8 tools / 2 resources (including the template) / 1 prompt**. PM-off leaves
**4 / 1 / 0**, with **6 blocked**; forum rules leave **3 / 1 / 0**, with
**7 blocked**; an orphan leaves **1 / 0 / 0**, with **10 blocked**. These
expectations are explicit; they do not calculate expected answers by calling
the content policy being tested.

Per-kind impact checks distinguish independent from marginal blocking: with
PM-off active, adding forum restrictions newly disables only `tool:u6_forum`.
With an orphan present, that marginal list is empty, even though the independent
forum `disables` list still includes it. The provider rule exercises registry
extensibility and its own contract. References include overlapping allow/deny
IDs, a real unlisted descendant, and missing IDs; a legacy missing-target row
is arranged with `update_columns` solely in the fixture.

## Decisions where the contract left room

- `content_restrictions.active` is a boolean meaning any stored rule exists,
  matching the policy's existing `active?` meaning; `blocked` is a distinct
  exposed-primitive count, not a sum over rules.
- All registered kinds are listed, including unavailable ones. An unavailable
  kind with a stored row is both an active registered entry and an orphan:
  `active` means row existence, while the orphan explains enforcement failure.
- Core component IDs equal their names. Explicit provider component IDs are
  preserved. For a provider registering no component, the test requires a
  string and deliberately leaves its fallback spelling open.
- Impact/reference/orphan arrays have no imposed sort order except the
  explicitly contracted rule registration order. References are the unique
  configured IDs, not expanded descendants; missing IDs remain in stored config.
- `restricted` is independent of enabled/emergency/availability. All primitive
  entries carry the policy result, while impact lists and overview counts
  consider only enabled, non-emergency-blocked, available entries.
- `restricts` is per-kind declaration impact: exposed primitives remaining
  usable under that kind and declaring `:enforced` for an affected data kind.
  It does not include content-free/untouched primitives or primitives that kind
  disables.
- Tag-name requests omit `tag_ids` on those sides. Numeric-ID configs are also
  exercised. Mixed `tag_names` plus `tag_ids` precedence is left open; nothing
  in the contract defines it.
- Missing categories may produce any 4xx with errors. That example first
  requires a successful PUT on the same route, so a missing route's generic
  404 cannot satisfy the refusal contract. Other contract/tag failures require
  exactly 400. Both new-row and existing-row refusal paths are asserted;
  rejected writes must preserve all existing row attributes and add no staff log.
- Staff log serialization/key names are open. The tests inspect the existing
  custom staff action type, actor, rule name and primitive-ID tokens in details.
  Saving while PM-off is already active must log only the newly blocked forum
  primitive, and an equivalent repeat save must log no primitive IDs.
- Consent is pinned to the supplied English text **“Disabled by site policy”**
  in the existing list item containing each requested PM scope's `code` node.
  No new CSS class, translation key or HTML element is assumed. Ordinary scopes
  stay unmarked; forum-only/no-row controls stay unmarked; removing PM-off
  restores the unmarked scope display. Consent GET creates no authorization.
- Rejection and role examples include a positive admin control. This avoids
  certifying an absent endpoint merely because it returns 404. Such controls
  are paired in the same example, so every unit 6 example has an observed RED
  assertion at this baseline while retaining its negative assertions.

## Contract faults and open ambiguities

- The handoff's section 10 says the updater logs updated/deleted rules “with
  the newly disabled primitives.” Deletion relaxes restrictions. The explicit
  contract here takes precedence: update details name newly disabled primitives;
  delete details need the rule name, with no invented deletion-impact field.
- “With no rows nothing in the existing payloads changes” must mean preserving
  existing semantics and fields: the same contract adds false `restricted`
  flags, the false access override flag, and an inactive overview summary.
- The explicit PM override formula names an active `private_messages` row or
  an orphan. Existing `ContentPolicy` also fails closed for a malformed stored
  registered config; a malformed `forum_content` row can therefore revoke PM
  scopes without either condition. That legacy-corruption case is not specified
  by the formula. These tests pin valid registered configs and both orphan
  cases; they do not silently choose a formula for malformed registered rows.
- No precedence is specified when clients send both tag names and IDs on one
  side, and no ordering is specified for impact arrays. Neither is invented here.

## RED inventory

**32 examples, all RED** in the final seed-68321 run. These are exact full RSpec names.

| File (relative to this directory) | Example name | Observed RED signature |
| --- | --- | --- |
| `admin_requests_spec.rb` | `Admin::McpController GET /admin/mcp/content-restrictions.json [cr-u6] lists registered kinds in registration order with string component ids and inactive metadata` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController GET /admin/mcp/content-restrictions.json [cr-u6] reports active stored config timestamp and updater including a null updater` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController GET /admin/mcp/content-restrictions.json [cr-u6] resolves both reference sides and reports missing ids once without expanding subtrees` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController GET /admin/mcp/content-restrictions.json [cr-u6] computes independent impact from declarations across primitive kinds and exposure states` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController GET /admin/mcp/content-restrictions.json [cr-u6] computes marginal impact against active rules and the orphan veto` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController GET /admin/mcp/content-restrictions.json [cr-u6] lists unregistered and unavailable orphans and restores the PM override on removal` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] creates and replaces one row with the actor and returns the full GET payload` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] resolves tag names on both sides and replaces the entire forum config` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] validates a registered provider contract rather than hardcoding core kinds` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] refuses invalid_contract without storing a new row or replacing an existing config` | HTTP 404; expected 400. |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] refuses missing_category without storing a new row or replacing an existing config` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] refuses unknown_tag without storing a new row or replacing an existing config` | HTTP 404; expected 400. |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] refuses writes to unregistered and unavailable kinds with 404` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController PUT /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] logs the rule and exactly the newly disabled primitive ids` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController DELETE /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] deletes private_messages with a staff log and returns 404 when repeated` | HTTP 404; expected 204. |
| `admin_requests_spec.rb` | `Admin::McpController DELETE /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] deletes u6:gone with a staff log and returns 404 when repeated` | HTTP 404; expected 204. |
| `admin_requests_spec.rb` | `Admin::McpController DELETE /admin/mcp/content-restrictions/:rule_kind.json [cr-u6] deletes u6:offline with a staff log and returns 404 when repeated` | HTTP 404; expected 204. |
| `admin_requests_spec.rb` | `Admin::McpController admin authorization [cr-u6] gives moderators 404 for content routes and existing admin MCP payloads without mutation` | HTTP 404; expected 200 (positive admin request/control). |
| `admin_requests_spec.rb` | `Admin::McpController admin authorization [cr-u6] gives users 404 for content routes and existing admin MCP payloads without mutation` | HTTP 404; expected 200 (positive admin request/control). |
| `consent_requests_spec.rb` | `McpOauthAuthorizationsController GET /oauth2/mcp/authorize [cr-u6] marks every requested PM scope disabled for private_messages and removes the marks when access returns` | Both PM scope list items contain only the scope name, without “Disabled by site policy”. HTTP 200 passed. |
| `consent_requests_spec.rb` | `McpOauthAuthorizationsController GET /oauth2/mcp/authorize [cr-u6] marks every requested PM scope disabled for u6:orphan and removes the marks when access returns` | Both PM scope list items contain only the scope name, without “Disabled by site policy”. HTTP 200 passed. |
| `consent_requests_spec.rb` | `McpOauthAuthorizationsController GET /oauth2/mcp/authorize [cr-u6] marks every requested PM scope disabled for u6:unavailable and removes the marks when access returns` | Both PM scope list items contain only the scope name, without “Disabled by site policy”. HTTP 200 passed. |
| `consent_requests_spec.rb` | `McpOauthAuthorizationsController GET /oauth2/mcp/authorize [cr-u6] keeps forum-only and no-row PM scopes unmarked while reflecting a later PM rule` | After adding PM-off, PM-read list item lacks “Disabled by site policy”; forum-only and no-row unmarked controls passed. |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/access.json [cr-u6] adds false restricted flags to access with no rows and preserves admin choices` | Primitive payload omits `restricted`; expected inclusion of `restricted: false` (other choice fields match). |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/capabilities.json [cr-u6] adds false restricted flags to capabilities with no rows and preserves admin choices` | Primitive payload omits `restricted`; expected inclusion of `restricted: false` (other choice fields match). |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/access.json [cr-u6] reports policy restrictions in access independently of enabled and emergency states` | `restricted` is nil/missing; expected true for `u6_disabled`. |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/capabilities.json [cr-u6] reports policy restrictions in capabilities independently of enabled and emergency states` | `restricted` is nil/missing; expected true for `u6_disabled`. |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/access.json [cr-u6] reports the orphan veto in access while leaving content-free primitives usable` | `restricted` is nil/missing; expected true for `u6_disabled`. |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/capabilities.json [cr-u6] reports the orphan veto in capabilities while leaving content-free primitives usable` | `restricted` is nil/missing; expected true for `u6_disabled`. |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/overview.json [cr-u6] preserves the no-rule catalog and adds an inactive zero-blocked summary` | Payload omits `content_restrictions: {active: false, blocked: 0}`; baseline counts 8/2/1 passed. |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/overview.json [cr-u6] counts only policy-usable exposed catalog entries and restores them after removal` | Catalog is 8 tools / 2 resources / 1 prompt; expected 4/1/0 under PM-off. |
| `existing_payloads_spec.rb` | `Admin::McpController GET /admin/mcp/overview.json [cr-u6] counts orphan-blocked exposed entries once even with multiple orphan rows` | Catalog is 8 tools / 2 resources / 1 prompt; expected 1/0/0 under the orphan veto. |

## Calibration and request limits

Every reported RED is an RSpec expectation failure, not a missing constant,
missing proposed method, parser error or fixture exception. The missing API
routes make many examples fail at their first positive HTTP status assertion;
this proves the example is RED, **not** that its later payload/persistence/log
assertions have independently failed. Those later assertions must execute and
pass after implementation. No temporary production implementation or mutation
was permitted by this job's edit boundary.

The fixture distinguishes plausible weaker implementations: full impact
versus marginal impact, counting all records versus exposed available ones,
counting overlapping orphan vetoes twice, equating enabled with usable,
blocking all declarations, hardcoding core rule kinds, returning IDs without
resolving names, dropping legacy missing IDs, and marking only one PM scope or
all requested scopes. The valid PUT control disqualifies a blanket 404 for
missing-category rejection. Provider fallback spelling, JSON log formatting,
and internal service/lock choices remain free.

Requests cannot certify FormKit interactions, client component registration,
card/fallback rendering, chooser behavior, dirty-state handling, confirmation
flows, responsive/theme appearance, the Capabilities state filter/reason UI,
the Activity label, help text, or the configured-responder warning. Those are
frontend/QUnit/system/visual gates owned by the implementer. The plain updater
class shape is deliberately untested. Atomicity under logger failure and all
possible concurrent API writes are not established by these request examples.
The real category delete/reparent concurrency pins live in unit 5 review 3.

## Run receipts

Final post-lint run: seed **68321**, **129 examples / 42 expected failures / zero
pending / zero errors outside examples**. All **32 new unit 6** and **10 new unit 5
review-3** examples fail by assertions. All **85 existing unit 5** and **2 unit 2
enrichment/inventory** examples pass. The seed-68320 combined run had the same
counts; the final run also uses an actual forum rule in the with-rule race and
allows the serialized update loser to report `ActiveRecord::RecordNotFound`.

```sh
hc run --bg --name cr-u6-final --cwd "$PWD" \
  'PATH=/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin:$PATH \
  LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit5 \
  spec/lib/discourse_mcp/content_restrictions_unit6 \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --seed 68321 --format documentation \
  --format json --out /tmp/cr-u6-final-68321.json'
```

Raw receipts: `/tmp/cr-u6-inventory-58319.json`,
`/tmp/cr-u5-review3-58319.json`, `/tmp/cr-u6-red-68319.json`,
`/tmp/cr-u6-combined-68320.json`, `/tmp/cr-u6-final-68321.json`.
The first unit 6 attempt is historical: it had a consent-registry fixture
returning 403, four missing-key exceptions, and a missing-category refusal
passing on the absent route. Those were corrected before the final two runs;
the table above uses only the final assertion-level signatures.

Final targeted `bin/lint --fix --verbose` passed RuboCop (**5 files, no offenses**)
and Syntax Tree using repo Ruby **4.0.7**, Bundler **4**, Node **24.14.0** and
pnpm **10.28.0**. An initial launch lacked the correct pnpm path, and a later
run caught an RSpec/ExpectActual style offense; both were corrected. No tests
were run against the core database, no migration was run, and no service was
started/stopped. HEAD remained `6bb68077df8`; concurrent frontend work in the
shared worktree was not edited by this oracle job.


## Review round 2: accepted findings, 2026-11-25

This section supersedes the original oracle's open mixed-input precedence and
config-audit decisions above. The historical seed/baseline receipts remain above;
the current results below concern the four accepted review findings for
`cc9cbf5b31c..385046637ba`. Actual execution HEAD was
**`b031cd231c97a29d944f83a63358773dae608c78`**, unchanged by this task.
Only `review2_spec.rb` (new) and this README were edited by this task.

The new file adds **24 request examples: 22 regression REDs and 2 GREEN controls**.
The final post-lint seed **68325** run has **56 examples / 22 expected failures /
0 pending / 0 errors outside examples**: all **32 pre-existing unit 6 examples
pass**, including legitimate PUTs, unknown-name refusals, existing payloads,
authorization, consent, and deletion controls. Every regression failure is an
RSpec expectation failure for the stated symptom, not a fixture/parser error.
Top-level failure aggregation allows both create/replace and preview/active
phases to execute even after an earlier failed expectation.

### New example names and observed signatures

| Exact example name (all in `review2_spec.rb`) | Observed result at HEAD |
| --- | --- |
| [cr-u6] applies allow synonym names to topics carrying the canonical tag | PUT 200; policy-visible IDs are `[]`, expected `[114620003]` (canonical-tag topic). |
| [cr-u6] refuses allow null tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] refuses allow scalar tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] refuses allow object tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] refuses allow mixed names and ids tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] applies deny synonym names to topics carrying the canonical tag | PUT 200; policy-visible IDs are `[114620003, 114620004]`, expected `[114620004]` (only the untagged topic). |
| [cr-u6] refuses deny null tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] refuses deny scalar tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] refuses deny object tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] refuses deny mixed names and ids tag input on create and replace without storage or logs | Both create and replace return 200 instead of 400, omit errors, change stored row attributes and append an update log. Both named refusal aggregations executed. |
| [cr-u6] controls valid names empty arrays numeric ids and unknown or non-string scalar names | GREEN: legitimate name arrays (case-insensitive, duplicate names), empty name arrays, numeric-ID saves, and refusal of mixed known/unknown names, nonempty object, number and boolean on both sides. |
| [cr-u6] logs a new forum rule's normalized stored config | PUT 200 and stored normalized IDs pass; audit `new_value` is nil instead of the stored config. |
| [cr-u6] logs previous and new stored configs when a forum rule is relaxed | Both PUTs return 200; replacement config and one new log pass. Both audit `previous_value` and `new_value` are nil instead of the old/new stored configs; zero newly disabled IDs passes. |
| [cr-u6] logs the removed stored config when a forum rule is deleted | PUT 200, DELETE 204, row removal and delete-log actor/type pass; audit `previous_value` is nil instead of removed config. |
| [cr-u6] reports revoked-scope primitives as disabled rather than restricted for private_messages | Preview `disables`/`newly_disables` and active `disables` omit all five scoped exposed IDs; preview and active `restricts` incorrectly include `tool:u6r2_filtered_write` and `prompt:u6r2_multi`. |
| [cr-u6] marks revoked-scope primitives restricted in capabilities under private_messages | HTTP 200; all eight scoped fixtures report `restricted: false`, expected true. Exposure flags and the ordinary profile-only `u6_none` control pass. |
| [cr-u6] marks revoked-scope primitives restricted in access under private_messages | HTTP 200; all eight scoped fixtures report `restricted: false`, expected true. Exposure flags and the ordinary profile-only `u6_none` control pass. |
| [cr-u6] counts revoked-scope primitives as blocked and removes them from the private_messages catalog | HTTP 200; blocked is 6, expected 11; catalog tools/resources/prompts is 6/3/1, expected 4/1/0. |
| [cr-u6] reports revoked-scope primitives as disabled rather than restricted for u6:review2_offline | Preview `disables`/`newly_disables` and active `disables` omit `tool:u6r2_none_read` and `resource_template:u6r2_none_write`; active newly-disables empty and restricts empty pass. |
| [cr-u6] marks revoked-scope primitives restricted in capabilities under u6:review2_offline | HTTP 200; `u6r2_none_read`, `u6r2_none_write`, and emergency-blocked `u6r2_emergency` report `restricted: false`, expected true; other scoped entries and ordinary `u6_none` control pass. |
| [cr-u6] marks revoked-scope primitives restricted in access under u6:review2_offline | HTTP 200; `u6r2_none_read`, `u6r2_none_write`, and emergency-blocked `u6r2_emergency` report `restricted: false`, expected true; other scoped entries and ordinary `u6_none` control pass. |
| [cr-u6] counts revoked-scope primitives as blocked and removes them from the u6:review2_offline catalog | HTTP 200; blocked is 13, expected 15; catalog tools/resources/prompts is 2/1/0, expected 1/0/0. |
| [cr-u6] logs exactly newly disabled ids including revoked scopes and respects an existing orphan | PUT 200; update log contains only six declaration-blocked IDs, missing all five scoped exposed IDs. Subsequent PUT with an existing orphan correctly logs no newly disabled IDs. |
| [cr-u6] controls scoped primitives with no rule a forum-only rule and after PM removal | GREEN: no-rule, forum-only, and PM removal states preserve false restricted flags for all eight scoped fixtures in both payloads and the expected catalog/blocked counts. |

### Decisions and reasons

- **Synonym contract:** save through PUT, then observe the loaded stored policy's
  `scope_topics` result for an actual canonical-tag topic and an untagged topic.
  This is the promised restriction's effect. It leaves canonicalization at save
  time versus synonym-aware evaluation free; no exact stored synonym ID is
  required. Separate allow/deny cases prevent a blanket allow/deny workaround.
  Uppercase synonym input also retains case-insensitive lookup coverage.
- **Invalid input:** either side must reject JSON null, a valid name sent as a
  scalar, an empty object, and simultaneous valid names/valid IDs. The two mixed
  representations identify different tags, so ignoring either representation
  cannot silently satisfy the contract. New-row and replacement requests each
  require 400 with errors, identical complete row attributes (including actor
  and timestamps), and unchanged content-rule staff-log IDs. Nonempty objects,
  numbers, booleans, and a known-plus-unknown array already refuse and remain
  GREEN controls. Empty arrays and duplicate/case-varied known names remain
  legitimate saves.
- **Scope impact:** use the existing registry API with actual
  `mcp:private-messages:read` and `mcp:private-messages:write` scopes. Five new
  exposed fixtures cover a content-free read tool, filtered write tool,
  untouched read resource, content-free write resource template, and a filtered
  prompt requiring both profile and PM-read. Three more scoped tools are
  disabled, emergency-blocked, or unavailable. None of their implementations
  may execute. Expectations are explicit, not computed from the policy gate.
  A revoked requirement disables even `:none` content and a mixed-scope primitive
  with another retained scope; otherwise the primitive is unusable despite the
  admin claiming it is available. Ordinary profile-only `u6_none` stays usable.
- **Orphan fixture:** an unavailable registered provider kind is used so the
  orphan also has an existing content-restrictions entry whose independent and
  marginal impact can be observed. Its stored row is arranged as a fixture
  because the legitimate PUT contract refuses unavailable kinds. All impact
  observations are GET responses. The PM rule itself is saved through PUT.
- **Exposure versus restriction:** capabilities/access must flag all eight scoped
  fixtures restricted, independent of their admin exposure choices. Only the
  five exposed, available fixtures enter impact/log lists and overview counts.
  With these fixtures there are 16 exposed primitives: PM-off must block 11
  (catalog 4/1/0), and the orphan must block 15 (catalog 1/0/0). A forum-only
  rule retains PM scopes (catalog 5/3/1); no rule gives catalog 10/4/2. Removing
  PM-off while retaining forum-only restrictions restores its counts.
- **Newly disabled audit IDs:** a first PM PUT must log precisely the baseline
  six declaration-blocked IDs plus all five scoped exposed IDs. With an orphan
  already active, adding PM-off must log no newly disabled IDs. This distinguishes
  independent impact from marginal impact and avoids double counting.
- **Config audit contract:** use the established `UserHistory.previous_value`
  and `new_value` fields, JSON-decoded rather than compared as formatted strings.
  These existing staff-audit fields give previous/new direction without a new
  production field or helper. Creation has no previous value and records the
  normalized stored config as new; update records both full snapshots; deletion
  records the removed snapshot as previous. The relaxation changes selected to
  all, clears both category sides and an allowed tag, removes one denied tag,
  and retains another. Logging only added/removed IDs, the request's tag names,
  or newly disabled primitives cannot reconstruct this transition. Actor and
  rule identity must remain present. JSON key order/whitespace are unconstrained.

### Fixture range and weaker implementations

Reserved range: **114_620_000..114_620_999**. Before writing the file, a recursive
filesystem scan of **2,739 Ruby/JSON files under `spec/`**, including ignored
paths and underscored/plain decimal literals, found no literal in that range.
This covers the unit suites and their support files; the existing unit 2
computed ID bases were also read (91/92/93/94 million). Used IDs in this file:
tags 114_620_001..002, 011..012, 021, 031..035; topics 003..004; categories
041..043. Existing unit 6 uses its separate 114_600_000..114_609_999 range.

The observed HEAD failures reject the current weaker behaviors directly:
lookup of the alias row alone, `Array(...)` coercion of null/scalars/empty
objects, overwriting IDs with names, declaration-only impact, unconditional
`:none` exemption despite revoked scopes, and logs containing only rule/disabled
IDs. The fixtures additionally discriminate against blanket rejection of names,
rejecting valid empty arrays, accepting unknown names alongside a known one,
blanket disabling all scopes under any rule, requiring every required scope to
be revoked instead of any one, including non-exposed records in counts, omitting restricted entries from the
capabilities/access payloads, and logging total rather than marginal impact. Those additional alternatives were
checked against the assertions and controls, not installed as temporary
production mutations; the edit boundary forbids that experiment.

### Receipts and limits

```sh
hc run --bg --name cr-u6-review2-final --cwd "$PWD" \
  'PATH=/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin:$PATH \
  LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit6 \
  --seed 68325 --format documentation \
  --format json --out /tmp/cr-u6-review2-68325.json'
```

Final JSON receipt: `/tmp/cr-u6-review2-68325.json`. Seed 68324 had the same 56/22 result before the final payload-presence
assertion; its receipt remains `/tmp/cr-u6-review2-68324.json`. Earlier seeds
68322/68323 are calibration receipts only: the first found a provider-prefix fixture error
and an empty-object coercion mistakenly included among controls; the final run
also uses the verified hyphenated PM scope names. These were fixture corrections,
not changes to production behavior.

Targeted `bin/lint --fix --verbose` passed RuboCop (one file, no offenses) and
Syntax Tree under repo Ruby 4.0.7 / Bundler 4.0.23. The first two lint launches
failed to locate pnpm; the successful launch supplied its installed directory
`/Users/saquetim/.local/share/mise/installs/pnpm/10.28.0` on PATH, alongside Node
24.14.0 and Ruby. No commit/stash/checkout/reset/amend/push, migration, core DB
access, or service start/stop was performed.

All four requested findings are pinned at request/public-policy/audit boundaries.
The unavailable orphan row is fixture setup rather than an impossible PUT.
No implementation fix or GREEN-after-fix claim is made. Frontend rendering,
concurrency, large-config audit truncation and logger-failure atomicity are not
established by these focused requests. No requested behavior was left unpinned.
