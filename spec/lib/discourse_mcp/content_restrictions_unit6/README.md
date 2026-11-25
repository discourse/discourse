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
