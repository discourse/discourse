# MCP content restrictions: unit 2 oracle

This directory is separately attributable test-only work. It does not load or modify the unit 1 oracle.
All example descriptions contain `[cr-u2]`. No implementation, locales or migrations changed.

## Harness and completeness

`fixtures.json` is the explicit argument, identifier-classification and expected-availability table:
107 core primitives and 9 in-repo plugin primitives (116 total at this source revision). Each has six
availability columns. The four forum-only configurations cover selected allowlist, denied category
including its child, a tag added **after** search indexing, and combined category/tag denies. The
sixth configuration additionally combines PM-off with the forum rule, so both interpretations of
“both together” are exercised.

`canary_spec.rb` compares this table to **all live registry entries**, before applying any policy or
availability filter. New primitives fail the fixture meta-check; unavailable plugins cannot quietly
shrink the matrix when `LOAD_PLUGINS=1`. Arguments and governed-ID variants are validated against the
live input schemas. An unavailable primitive fails with its missing prerequisite. With plugins off,
plugin cells report an explicit skip, and missing core fixtures still fail the meta-check.

The administrator's issued token requests every live scope. Requests use `DiscourseMcp::Server` for
tools, templates and prompts; the policy, renderer and serializers are real. Nothing stubs or bypasses
the egress tripwire. Unit 1's server currently has no egress tripwire; unit 3 must add it. The matrix
will continue calling through the same server when it exists.

Each configuration setup contains nine uniquely marked canaries and their notification, action, bookmark, draft,
flagged reviewable, revision, badge grant, webhook payload and attached-upload records. The tagged
category has its definition-topic association. The restricted-author fixture owns only restricted
posts. A public flagged reviewable has a restricted PM conversation. The labeled-link post is created
through the server; WebMock supplies an actual redirect, and `Jobs::CrawlTopicLink` executes to verify
the restricted title reached the link record. The summary fixture targets the admin who authored
that labeled link; a supplemental summary probe retains the restricted-author coverage. The
unrestricted title calibration uses the same fixture arguments as the matrix. A calibration example proves every primary canary is
readable through the unrestricted server and every related record persisted.

The six configurations each run as one example, sharing their setup across all 116 primitive cells.
The unrestricted calibration builds a seventh dataset. This replaces 697 full builds with seven;
there are still 696 separately labeled matrix cells and every governed-ID variant is retained.
A nested `aggregate_failures("<configuration> <key>")` identifies each failing cell and allows the
remaining cells to run. Select a configuration with `--example "[cr-u2] pm_off "`, for example.
Each configuration prints its elapsed seconds, including setup, so a local run can verify the
approximately 20-minute target. That wall-clock target has not been measured in this sandbox.

Each cell rolls back argument-resolution records and primitive exposure changes. Each request gets a
fresh context and a further rollback savepoint. The issued token is materialized before that
savepoint, and the full response is JSON-round-tripped before rollback. Deferred work is drained
inside the request transaction; afterward, the in-memory settings provider is restored and refreshed;
local distributed caches, Redis/cache state and queued Sidekiq work are cleared. Thus later requests start from the shared
seed database even after writes. Calibration checks both a rolled-back topic edit followed by a fresh
read and an in-memory site-title update. The labeled-link seed deliberately persists until the
configuration's outer example transaction rolls back.
Checks cover status, headers, full result, errors, structured content, resource text and prompt
messages. All restricted tokens, primary topic/post/category/tag/upload IDs, URLs and upload short
URLs must be absent. Restricted and missing governed targets must have **exactly equal** responses
after replacing only the caller's own exact echoed argument at declared `request_echoes` paths.
`GetDraft` declares its structured `draft_key` and the same top-level key inside its JSON text part.
No other path is exempt: another ID, nested draft key, header, error, or extra text still fails.
The substitution preserves JSON text whitespace and all unrelated bytes; the missing response is
never normalized. The absence check runs on the same substituted response, so it exempts only that
caller-owned echo. Related-record metadata such as a badge grant ID or webhook
delivery ID is not itself a restricted topic/post ID; the plan explicitly permits redacted metadata.

Token detection retains the exact serialized-response check and also scans individual strings,
including keys, headers, errors, structured content, resource text and prompt messages. JSON text
documents are decoded recursively. HTML entities, Unicode compatibility forms, case, whitespace and
punctuation are normalized for matching; both the complete token phrase and its unique random suffix
are checked. The suffix catches title/slug/excerpt transformations that interrupt the descriptive
words or return only part of the phrase. Allowed canaries remain excluded from the restricted set.
URL, identifier, authentication, availability and exact-response comparisons retain their checks.

Configuration/account/theme/query IDs and pagination cursors have explicit unaffected classifications
rather than invented “restricted” counterparts. An unrelated account does not become invisible just
because all its posts are restricted. Governed topic/post/category/draft/reviewable/upload targets,
including optional IDs and post-ID arrays, get restricted/missing variants.

## Category restriction decision

A category is restricted when **any** of these conditions holds:

- It belongs to a denied category's subtree.
- Allow mode is `selected` and it is outside every selected category's subtree.
- Its definition topic carries a denied tag.

This applies even when the category is empty. Its name, slug, description and identifiers must
not reach the agent. Get, update, delete, create-category parent and create-topic category targets
must answer exactly like missing targets; the matrix retains each restricted/missing comparison.
Selecting a child does not select its ancestors. An allowed topic must not disclose a restricted
ancestor through `parent_category_id`, category-ID arrays or side-loaded category records.

The allowlist selects the original allowed category and a child of the excluded `@outside` category.
The shared allowed topic now belongs to that selected child, exercising the restricted-parent case
through all topic reads, resources, prompts and writes that use `$topic_id` or `$post_id`.
`discourse_create_topic`, `discourse_save_draft`, `discourse_get_category` and
`discourse_update_category` retain their permitted `$category_id` target. Two fixtures change:

- `discourse_delete_category`: `$empty_category_id` / `$empty_category_name` resolve to an empty
  child of the original allowed category. A separate excluded top-level empty category remains a
  restricted/missing target.
- `discourse_create_category`: adds `parent_category_id: "$category_id"`, so the prospective new
  category belongs to an allowed subtree.

The allowlist's category targets and restricted IDs include **all** categories in the seeded database
outside these permitted subtrees, including uncategorized and other pre-existing categories. Their
names, slugs and descriptions are checked across normalized response strings and decoded JSON text.
All original fixed canary IDs retain their full-response absence check. Newly covered pre-existing
category IDs additionally use category-field context, including headers, nested records and ID-keyed
maps: ID `1` in a category field is a leak, while protocol request ID `1` or counter `1` is not.
This avoids false positives without exempting any previously covered canary or altering the
restricted/missing response comparison.

The availability table is independent of `primitive_usable?` and `ContentPolicy`: a usable fixture must
succeed, and a blocked fixture must return the policy-blocked error. Accepting any error, deriving
expected availability from the gate under test, disabling the tripwire, and broadly replacing IDs
were rejected because they hide the defects this oracle needs to catch. The `signups` report fixture is content-free and usable under the plan in every configuration.
Unit 1 currently blocks it; this is a predicted failure rather than a phase-specific exception to the
availability table. See [AVAILABILITY_AUDIT.md](AVAILABILITY_AUDIT.md) for the rule applied to every row.

## Enrichment inventory

`enrichment_inventory.json` has **56 operation rows covering all 55 write primitives**, with **116
shared path nodes**. Each operation names one MCP tool, trigger, raw source, evidence and downstream
paths. Empty paths require `cooks_nothing: true` with a reason. Shared paths form a graph; cycles
represent ordinary posts/revisions emitted by bot, automation and workflow responses. Each evidence
entry stores the exact file, line and source text. `enrichment_spec.rb` checks live registry coverage,
references and every evidence line, including excluded lookalikes.

Searches covered core MCP registrations/implementations, every in-repo plugin registration, model
callbacks, PostCreator/PostRevisor/PostDestroyer, jobs, cooked processors, validation/filter hooks and
plugin event registration (including dynamic workflow subscriptions). Searches included ignored Ruby
files and multiline registration forms. Lookalikes were checked against actual routing: for example,
blog publication requires `blog_id`, which current MCP tools cannot submit, and board synchronization
does not call the separate constraint-fix UI service. These exclusions are recorded with evidence.

The inventory includes future rebakes, hotlink downloads/raw rewrites, quote/onebox/local-handler
lookups, labeled-link title crawling, localization, category definition posts, reviewable approvals
and feedback PMs, historical recovery raw, group bios, group-mention rewrites, system/status posts,
conditional AI/event/poll/policy/assignment hooks, and configured automation/workflow destinations.
No write primitive is unclassified. Exact configured script bodies, destinations and bot responses
are runtime data and remain open boundaries, explicitly recorded under `unresolved`. Static registry
coverage does not prove all configurable paths are policy-safe. The canaries do not drain every
conditional plugin job; the inventory is the review input for those paths and unit 4's write tests.

## Availability and expected results at unit 1

[AVAILABILITY_AUDIT.md](AVAILABILITY_AUDIT.md) re-derives all 116 rows from plan section 8,
the Decisions list, and section 11. Each `fixtures.json` row stores its `availability_rule`
(plan basis and blocked condition), independently of the live certification gate.

`expected_status.json` enumerates the exact RED cells and their GREEN complements. These are
predictions for unit 1, not expectations that policy leaks are acceptable. All negative content,
identifier, URL and restricted/missing assertions remain active.

| Configuration | Predicted RED | Predicted GREEN |
| --- | ---: | ---: |
| `pm_off` | 3 | 113 |
| `allowlist` | 88 | 28 |
| `denied_category` | 88 | 28 |
| `denied_tag` | 88 | 28 |
| `combined` | 88 | 28 |
| `pm_off_and_forum` | 82 | 34 |

The category decision adds probes within existing cells, so these unit 1 predictions remain unchanged
(437 RED and 259 GREEN across 696 cells). They are not predictions of the concurrently changing unit 3
implementation; only the harness was rerun for this amendment.

PM-off predicts the crawled-title leak, content-free `signups` report blocked, and webhook ping
blocked. Every forum row predicts the orphan veto for each planned-usable non-`:none` primitive,
including reactions, solved, voting, and events. Exit-path writes are blocked under any rule;
dedicated PM tools and membership-request handling are blocked under PM-off; all tag-group writes
are blocked under every forum configuration, including delete and category-only rules.

Before installing each configuration's rules, the harness proves that the unrestricted admin
`get_user_summary.top_links` contains the labeled-link URL and the exact crawled restricted title,
and that the returned response contains the redirect token. This calibrates the actual output path,
in addition to checking the persisted `TopicLink`. PM-off must reject the redirect token in the
primary admin-summary response, so the current implementation is expected RED for `crawled_title`.
The primary fixture exercises the calibrated output directly, while the restricted-author probe
remains active.

A subsequent seed-12431 baseline caught the exact redirect token with the original restricted-output
assertion, but RSpec emitted that single failure without its inner cell label. RSpec promotes a lone
aggregate failure directly; only multiple failures retain the aggregation heading. Counting only
`failure aggregation block` headings therefore misclassifies the summary cell as GREEN. Restricted
output assertions now include the configuration and primitive directly in their failure messages;
a token leak says `[cr-u2] pm_off tool:discourse_get_user_summary: RED restricted canary tokens ...`
even when it is the only failure. The redirect calibration explicitly verifies restricted-post and
restricted-token membership before crawling, ruling out missing membership or early computation.

Blocked cells require one of two exact legitimate envelopes: HTTP 400 JSON-RPC policy error
`-32602`, or HTTP 200 tool error with only the policy message, `isError: true`, and complete-result
metadata. Neither arbitrary errors nor extra result content pass. This covers gate refusals and
PM-off membership-request handling without deriving availability from either implementation.

## Run status

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit2/
```

The latest detection run and mutation checks are recorded in
[verification.json](verification.json); the earlier availability work is recorded in
[AVAILABILITY_AUDIT.md](AVAILABILITY_AUDIT.md). The standalone harness runs without Rails/Redis:

```sh
bundle exec rspec --options /dev/null -Ilib \
  spec/lib/discourse_mcp/content_restrictions_unit2/harness_spec.rb
```

Its twenty-one examples cover text quality, explicit draft seeds, plugin presence/absence,
schema identifier coverage, strict caller-echo substitution, every plan-based availability row,
both legitimate blocked response envelopes with malformed/extra-content rejection cases, every
canary's normalized title/slug/excerpt forms across all six configurations, isolated response
surfaces with escaped JSON text, attribution of a single output failure to its matrix cell,
complete excluded-category coverage, permitted category fixtures, restricted parent IDs alongside
allowed topics, and pre-existing category IDs on each response surface without counter/protocol collisions.
The constant helper explicitly dispatches to RSpec's two-argument constant stubbing API, avoiding
Discourse's three-argument helper. The I18n stub also avoids the Mocha/RSpec `anything` collision.

## Plan corrections for review

- Request echoes use the accepted caller-argument substitution rule above. The PM-off user-summary
  crawled-title leak remains an accepted defect under section 3.
- `UpdateTopic` always schedules post-processing through PostRevisor, but does not always recook raw:
  the Post save callback cooks when raw changes, and `trigger_post_process` does not set `cook:true`.
  Existing cooked oneboxes/quotes/media still require checking.
- Unhide is not an unconditional rebake. `Post#unhide!` saves hidden/status fields. Recovery does extract
  links, and user recovery can restore **historical deletion-revision raw**, which must also be checked.
- Checking only the submitted/target post misses group saves cooking unchanged `bio_raw`, group renames
  recooking every matching existing mention post, and category moves rebaking **other posts** through
  upload-security jobs. Group bio and membership templates also deserve explicit write-field coverage.
- Arbitrary configured automation/workflows and bots can select different stored content and produce
  new raw. Their outputs are not bounded by validating the triggering MCP argument alone. The plan
  corrections above are accepted input to unit 4's write rules. The configured automation/workflow/bot
  boundary is a user scope decision; this harness does not silently resolve that decision.

## Unit 3 evidence refresh at `3af1cfab93a`

Re-reviewed 91 moved evidence occurrences (85 distinct file/line locations) against the current implementation and `fc63dd894d5..3af1cfab93a`, including every registry implementation binding. The 56 operation rows, 55 write primitives, 116 shared paths and three exclusions are retained. Repeated evidence for UpdateGroup, moderation registration and the username exclusion accounts for the occurrence/location difference.

| Evidence file | Old → current lines | Review result |
| --- | --- | --- |
| `lib/discourse_mcp/core_primitives.rb` | 423 → 436, 439 → 452, 466 → 479, 482 → 495, 497 → 510, 637 → 650, 649 → 662, 661 → 674, 694 → 707, 742 → 755, 799 → 812, 1396 → 1409, 1437 → 1450, 1471 → 1484, 1499 → 1512, 1554 → 1567, 1614 → 1627, 1651 → 1664, 1707 → 1720, 1740 → 1753, 1787 → 1800, 1801 → 1814, 1853 → 1866, 1877 → 1890, 1915 → 1928, 1939 → 1952, 2005 → 2018, 2191 → 2204, 2312 → 2325, 2353 → 2366, 2434 → 2447, 2476 → 2489, 2581 → 2594, 2596 → 2609, 2631 → 2644, 2660 → 2673, 2673 → 2686, 2706 → 2719, 2986 → 2999, 3025 → 3038, 3053 → 3066, 3079 → 3092, 3106 → 3119, 3138 → 3151, 3164 → 3177, 3191 → 3204, 3300 → 3313, 3364 → 3377 | Registrations still bind to the same implementations; forum-rule registration adds 13 preceding lines. |
| `lib/discourse_mcp/tools/topic_writes.rb` | 135 → 139, 156 → 166, 214 → 224, 261 → 271, 382 → 405 | Policy checks precede existing submissions/revisions/deletion; moves/retags get a stored-result rollback check. Blog remains excluded by the explicit submission fields. |
| `lib/discourse_mcp/tools/private_messages.rb` | 230 → 238, 294 → 302, 336 → 341 | Policy-aware PM lookups guard replies and invitations; PostCreator paths remain. |
| `lib/discourse_mcp/tools/categories.rb` | 80 → 96, 137 → 164, 168 → 202 | Restricted targets/parents are rejected; re-parenting is blocked under forum rules; existing definition-post paths remain. |
| `lib/discourse_mcp/tools/moderation.rb` | 530 → 653, 569 → 692 | Policy-aware lookup/action guards narrow dispatch and feedback reachability. |
| `lib/discourse_mcp/tools/users.rb` | 622 → 656, 655 → 689, 717 → 751 | Profile mutation allowlist still excludes username; only declarations changed for this write. SetUserStatus still cooks nothing. |
| `lib/discourse_mcp/tools/groups.rb` | 357 → 400, 410 → 454, 452 → 497, 484 → 529, 537 → 582, 579 → 624, 620 → 665, 673 → 718 | Defaults mutation is guarded; acceptance can skip a restricted request PM. Existing save/bio/rename/membership paths remain. |
| `lib/discourse_mcp/tools/drafts.rb` | 91 → 100, 160 → 169 | Shared topic lookup now guards restricted keys before set/clear; backup branches remain. |
| `lib/discourse_mcp/tools/tag_groups.rb` | 194 → 215, 214 → 237, 237 → 262 | Write bodies retain creator/updater/destroyer and remain uncertified under forum rules; create/update output uses policy-aware projection. |
| `lib/discourse_mcp/tools/web_hooks.rb` | 430 → 432, 458 → 460, 488 → 490, 514 → 516, 551 → 554 | Bodies retain the same no-cooking classification. Delete is now classified untouched; ping remains content-free and replay remains uncertified. |
| `lib/discourse_mcp/tools/site_settings.rb` | 220 → 269, 283 → 332 | Read-side redaction shifted the write; update and setting/rebake hooks remain unchanged and uncertified under rules. |
| `lib/group_membership_request_handler.rb` | 50 → 55 | New reply_allowed callback suppresses the acceptance post for a restricted request PM while preserving membership/request handling. |

Changed reachability is recorded on the affected operations and on shared paths `reviewable_action`, `membership_accept` and `settings` using `unit3_review`. The generic Server egress change is recorded once in the inventory metadata. Native cooking/job/event implementations retain their graph edges; these remain conditional paths, not a claim that unit 3 makes every path safe. Theme code and copied raw source remain open boundaries. The Blog and UpdateUsername exclusions remain valid; Boards evidence did not move.

## Round 2 evidence refresh at `c560ace5708`

Observed the exact-line example RED before editing: 15 stale evidence occurrences, first `groups.rb:400`. Re-read all 15 against the current method bodies and the `3af1cfab93a..c560ace5708` diff. There are 13 distinct locations: UpdateGroup appears twice, and SetThemeCode is also the shared `theme_code` path. The 56 operation rows, 55 write primitives, 116 paths and three exclusions remain unchanged.

| Evidence file | Prior → current lines | Review result |
| --- | --- | --- |
| `lib/discourse_mcp/tools/groups.rb` | 400 → 401, 454 → 455, 497 → 498, 529 → 530, 582 → 583, 624 → 625, 665 → 666, 718 → 719 | Expanded PM-field comment shifts declarations by one line. Group write bodies and downstream paths remain. UpdateGroup detail output now omits message metadata under any active rule, and shared tag-hash filtering changes notification-default output. |
| `lib/discourse_mcp/tools/site_settings.rb` | 269 → 270, 332 → 333 | The read-side guard now also redacts PM URLs under PM-only policy, shifting the write by one line. UpdateSiteSetting and native setting/rebake hooks remain unchanged and uncertified under active rules. |
| `lib/discourse_mcp/tools/themes.rb` | 190 → 247, 291 → 350, 326 → 387 | New typed category/tag redaction precedes the declarations. SetThemeCode/CreateTheme/UpdateTheme pass policy into shared theme_json; compilation, mutations and cooking edges remain unchanged. These writes remain uncertified under active rules. |

The inventory records every affected row and exact move under `round2_review`; it preserves the previous review as historical evidence. Shared `settings` and `theme_code` paths have explicit re-review notes. The new round-2 oracle separately tests the remaining typed topic/post and local-route URL gaps.

Validation at `c560ace5708`, seed `20914`: both enrichment examples pass after the refresh. All 245 exact evidence occurrences and graph references were also rechecked directly. See [round-2 verification](../content_restrictions_unit3/round2_verification.json) for the before/after results.

## Unit 4 item B evidence refresh at `ae8d882a477`

Observed the exact-line example RED before editing: six assertion failures at five distinct locations. Re-read every moved declaration and shared call in the current method bodies. All operation/path classifications and graph edges remain unchanged.

| Evidence file | Prior → current lines | Review result |
| --- | --- | --- |
| `lib/discourse_mcp/tools/site_settings.rb` | 270 → 327, 333 → 390 | Read-side projection/redaction support shifted UpdateSiteSetting and its shared update! call. The write still invokes SiteSetting::Update; setting/rebake hooks and unenforced declarations remain. |
| `lib/discourse_mcp/tools/themes.rb` | 247 → 254, 350 → 357, 387 → 394 | Preceding theme support shifted SetThemeCode/CreateTheme/UpdateTheme. Re-read their compilation, service and save bodies; their cooking edges and unenforced declarations remain. SetThemeCode occurs twice because it also anchors the shared theme_code path. |

The machine-readable moves and row reviews are under `unit4_refresh_review`. Before/after run receipts are recorded in [unit 4 verification](../content_restrictions_unit4/verification.json).

## Round 3 evidence refresh at `6a77b9b3e85`

Observed the exact-line example RED before editing: **19 stale evidence occurrences
at 18 distinct locations**. UpdateGroup appears twice, once for bio/membership and
once for rename rewrites. Re-read every moved declaration or call in its current
body and reviewed `ae8d882a477..6a77b9b3e85`, including the shared Server input gate,
prospective-topic checks and upload grants. Historical review notes above and in
the inventory describe their named revisions; `round3_review` records this HEAD.

| Evidence file | Prior → current lines | Re-review and unit 4 behavior |
| --- | --- | --- |
| `lib/discourse_mcp/tools/topic_writes.rb` | ReplyTopic 166 → 172; EditPost 224 → 230; UpdateTopic 271 → 282; SetPostDeleted 405 → 436; submission `category: category_id` 139 → 145 | Reply still uses NewPostManager. Creation now checks prospective category/effective tags, including word-watcher tags and required parents. EditPost refuses non-regular cook methods under active rules. UpdateTopic checks stored first-post raw and effective targets, and refuses category changes with secure uploads enabled. Recovery checks current raw and the previous deletion-revision raw for user-deleted posts. Blog remains excluded: the submission allowlist still does not forward `blog_id`. |
| `lib/discourse_mcp/tools/moderation.rb` | PerformReviewableAction 653 → 683; `reviewable.perform` 692 → 723 | Before dispatch, publishing actions check queued title/raw; restoring actions check stored target-post raw. Earlier account-deletion and additional-fields refusals remain. Shared `reviewable_action`, `queued_approve`, `recover` and `reviewable_feedback` paths retain their native edges after these gates. This does not certify arbitrary plugin actions or generated templates. |
| `lib/discourse_mcp/tools/groups.rb` | CreateGroup 401 → 416; UpdateGroup 455 → 470 (twice); DeleteGroup 498 → 514; ManageGroupMembers 530 → 546; InviteGroupMembers 583 → 599; ManageGroupOwners 625 → 641; ManageGroupMembership 666 → 682; HandleGroupMembershipRequest 719 → 735 | UpdateGroup now checks unchanged stored bio when no replacement is supplied and refuses changed names under active rules. The MCP `group_rename` path is suppressed under those rules; `group_bio` remains after text validation. Re-read all other mutation branches, service calls, confirmation checks and acceptance callback: their native membership/notification/destruction behavior is unchanged. Supplied group fields and membership-request reasons now also pass the shared Server text gate. |
| `lib/discourse_mcp/tools/drafts.rb` | DeleteDraft 169 → 193 | SaveDraft additions move DeleteDraft, whose checks and Draft.clear remain unchanged. SaveDraft checks supplied effective tags and passes `backup: false` under every active rule; every `draft_backup` creation/fast-update/revision branch is suppressed for those calls. Ordinary draft storage and unrestricted backups remain. |
| `app/models/draft.rb` | `cooked: PrettyText.cook(draft_body)` 299 → 301 | The fast-update branch itself is unchanged. Draft.set's new `backup:` argument gates entry to the whole backup path, including this call. Other callers retain the default `backup: true`. |
| `lib/discourse_mcp/tools/users.rb` | SetUserStatus 751 → 753 | Status set/clear still cooks nothing; the Server now checks supplied descriptions. Preceding CreateUser/UpdateUser upload checks now accept usable authorization grants instead of refusing every upload reference under active rules. Profile/save/event paths remain after the text and grant checks. |

Some behavior changed without moving existing evidence. The following table
records those entry conditions as well; the inventory has matching operation/path
notes. Native renderer, job and event bodies were not changed by this diff.

| Current source | Affected paths | Unit 4 change |
| --- | --- | --- |
| `lib/discourse_mcp/server.rb` `call_tool`; `lib/discourse_mcp/authored_text.rb` `AUTHORED_ARGUMENTS` / `allowed?` | MCP entry to `post_create`, `revision`, `category_create`, `category_update`, `group_bio`, `membership_request`, `profile`, `user_events`, `system_message`, `silence`, `suspend` and draft storage | Supplied fields selected by the explicit tool/argument allowlist pass authored-text validation while any rule is active. The check cooks with `onebox_limit: "none"` to inspect references before implementation dispatch. This adds a render pass; it does not check every stored/generated template or remove native downstream edges. Labelled external links can still reach `link_extract` / `crawl`. |
| `lib/discourse_mcp/tool_helpers.rb` `ensure_prospective_topic!` / `prospective_tag_ids!`; `lib/discourse_mcp/tools/topic_writes.rb` CreateTopic / UpdateTopic | `post_create`, `queued_approve`, `revision`, `upload_security` | Creation/update check prospective category and effective tags; UpdateTopic additionally checks stored first-post text. Category moves cannot reach upload-security rebakes while both secure uploads and a rule are active. |
| `lib/discourse_mcp/tools/uploads.rb` UploadFile; `lib/discourse_mcp/upload_grants.rb`; `lib/discourse_mcp/tools/users.rb` CreateUser / UpdateUser | `upload`, `profile`, `user_events` and checked media in authored text | Fresh MCP uploads now receive an authorization grant. Reuse/assignment requires a grant with no reference outside recorded targets. Server records new reference targets after implementation. URL-source and freshness/deduplication refusals already existed at the baseline; they are not new unit 4 behavior. |
| `lib/discourse_mcp/server.rb` `tool_error_text` | Tool-error output for every path | Active-rule tool errors pass only fixed server messages; other text becomes a generic refusal. This output change does not prove that a preceding mutation or job was safe. |

All **245 exact evidence occurrences** and graph references are revalidated after
refresh. Both enrichment examples pass. The inventory retains **56 operation rows,
55 distinct write primitives, 116 native paths and three exclusions**. Conditional
edges remain for unrestricted calls and other native callers; changed MCP entry
conditions are recorded rather than erased from the graph. The complete 19-move
list is in `enrichment_inventory.json` → `round3_review.moves`. Run receipts and the
new URL examples are in [the unit 3 round-3 report](../content_restrictions_unit3/ROUND3.md).

## Unit 4 review 1 evidence refresh at `ec0c8a3ac52`

The exact-line example failed at the two site-setting locations before this
refresh. Re-read both current bodies and the `ec0c8a3ac52` diff: the unit 3
round 3 URL resolution changes precede these entries and move both by 84 lines.

| Evidence file | Prior → current lines | Re-review result |
| --- | --- | --- |
| `lib/discourse_mcp/tools/site_settings.rb` | UpdateSiteSetting 327 → 411; `SiteSettingSupport.update!` 390 → 474 | The write retains its unenforced declarations, confirmation/dependency/current-value checks, service update and verification. The shared update! helper still calls SiteSetting::Update. Native setting hooks and later rebakes retain their classification; only preceding read-side URL resolution changed. |

Both enrichment examples pass after the refresh. Historical move records are
retained; the live evidence entries and `unit4_review1_refresh` describe this
revision. See [unit 4 review 1](../content_restrictions_unit4/REVIEW1.md) for run receipts.

## Unit 4 review 2 evidence refresh at `cc81b6c5ea2`

The baseline exact-line example (seed `28553`) failed at exactly four stale
occurrences. Re-read each current declaration/call and its surrounding body,
and reviewed `446abae79e3..cc81b6c5ea2` before updating the live evidence.

| Evidence file | Prior → current lines | Re-review result |
| --- | --- | --- |
| `lib/discourse_mcp/tools/moderation.rb` | PerformReviewableAction 683 → 702; `reviewable.perform` 723 → 742 | Publishing now includes `approve_post_closed`; queued new topics check prospective category/effective tags before dispatch. Stored-text, lookup, account-deletion and additional-fields guards remain. Native approval/recovery/unhide/feedback edges remain conditional on these gates; arbitrary plugin actions are not certified. |
| `lib/discourse_mcp/tools/private_messages.rb` | ReplyPrivateMessage 302 → 310; InviteToPrivateMessage 341 → 349 | Preceding CreatePrivateMessage now checks prospective watched-word tags and PM policy before PostCreator. Reply retains its policy-aware PM lookup and PostCreator; invitation retains recipient validation, lookup and invite/notification branches. Native graph edges and classifications remain. |

The inventory preserves historical reviews and adds `unit4_review2_refresh` to
these operations, PM creation and the shared approval/dispatch paths. All 245
live exact evidence occurrences and graph references were rechecked directly;
56 operation rows, 55 distinct primitives, 116 paths and three exclusions remain.
The post-refresh spec receipt is recorded in
[review 2](../content_restrictions_unit4/REVIEW2.md).

## Unit 4 review 3 evidence refresh at `7d1edac2d9b`

Seed **73019** observed the exact-line example fail at all four stale locations
before this refresh. Current declarations/calls and the
`4df55a811ad..7d1edac2d9b` diff were re-read:

| Source | Evidence move | Review |
| --- | --- | --- |
| `lib/discourse_mcp/tools/moderation.rb` | `PerformReviewableAction` 702 → 704; `reviewable.perform` 742 → 744 | Queued prospective validation now reads `reviewable.create_options`, including hash tags by name and the reviewable category. Permitted dispatch and downstream edges remain conditional. |
| `lib/discourse_mcp/tools/site_settings.rb` | `UpdateSiteSetting` 411 → 479; `SiteSettingSupport.update!` 474 → 542 | Read-side URL guarding grew; the write remains unenforced and retains its setting-change/rebake edges. |

`unit4_review3_refresh` records these moves; prior refresh metadata remains
historical. All **245 live evidence occurrences** and graph references were
checked twice directly after the update. Counts remain **56 operation rows,
55 distinct write primitives, 116 paths, three exclusions**. The post-refresh
RSpec result is recorded in [REVIEW3.md](../content_restrictions_unit4/REVIEW3.md).

## Unit 4 review 4 evidence refresh at `6bb81ffd390`

Seed **84019** observed the exact-line example fail at `moderation.rb:704`
before editing. The same run then hit an out-of-range site-settings reference
at line 479, which prevented it from reaching the remaining rows. Directly
checking all 245 live evidence occurrences found exactly four stale locations:

| Source | Evidence move | Re-review |
| --- | --- | --- |
| `lib/discourse_mcp/tools/moderation.rb` | `PerformReviewableAction` 704 → 714; `reviewable.perform` 744 → 754 | Prospective queued-topic validation now selects the staff reviewer's guardian or the non-staff queued author's guardian. Publishing/stored-text guards and permitted native dispatch remain. Category filtering and approval's tag fallback still require the review-4 regression coverage. |
| `lib/discourse_mcp/tools/site_settings.rb` | `UpdateSiteSetting` 479 → 277; `SiteSettingSupport.update!` 542 → 340 | Read-side URL handling now uses an origin boundary instead of route/model inference. The write retains its unenforced declarations, confirmation/dependency/current-value checks, service update and verification. Native setting/rebake edges remain conditional. |

The current bodies and `9568245c408..6bb81ffd390` were re-read before refreshing
the live entries. `unit4_review4_refresh` records the four moves and changed
entry conditions; previous review metadata remains historical. Counts and graph
edges remain **245 evidence occurrences, 56 operation rows, 55 distinct write
primitives, 116 paths and three exclusions**. Both enrichment examples pass in
the combined review-4 run. Names, RED signatures, calibration limits and run
receipts are recorded in [REVIEW4.md](../content_restrictions_unit4/REVIEW4.md).

## Unit 4 review 5 evidence refresh at `e775091f75f`

Seed **85019** observed ten stale live evidence occurrences at ten distinct
locations before editing: **2 examples, 1 failure**. This HEAD did not reproduce
an `IndexError`. Each current declaration/call and the
`8a32e9ce84d..e775091f75f` diff were read before refreshing:

| Source | Evidence moves | Re-review |
| --- | --- | --- |
| `lib/discourse_mcp/tools/moderation.rb` | `reviewable.perform` 754 → 759 | Dispatch now runs in a stored-topic transaction using `created_post_topic`. Native approval/recovery/feedback paths remain conditional. Revise/reject's system PM does not populate that field; the new review-5 spec pins the PM-rule bypass. |
| `lib/discourse_mcp/tools/private_messages.rb` | ReplyPrivateMessage 310 → 315; InviteToPrivateMessage 349 → 354 | CreatePrivateMessage gains a stored-topic transaction around PostCreator. Reply and invitation bodies retain their native paths. |
| `lib/discourse_mcp/tools/site_settings.rb` | UpdateSiteSetting 277 → 289; update! call 340 → 352 | Browser-oriented read-side URL handling shifts the write, whose unenforced declarations, service checks and native setting/rebake paths remain. |
| `lib/discourse_mcp/tools/topic_writes.rb` | submission category 145 → 152; ReplyTopic 172 → 180; EditPost 230 → 238; UpdateTopic 282 → 290; SetPostDeleted 436 → 444 | CreateTopic gains a stored-topic transaction. Subsequent write bodies and conditional graph edges remain; the explicit submission fields still exclude `blog_id`. |

`unit4_review5_refresh` records these moves and entry conditions; historical
reviews remain intact. All **245 live evidence occurrences** and graph references
were checked twice after refreshing. Counts remain **56 operation rows, 55
distinct write primitives, 116 native paths and three exclusions**.

Both enrichment examples pass in the combined seed-85019 run, with no
`IndexError`. The combined run has 40 examples and 21 intentional regression
failures from the new review-5 specs. Exact new example names, observed RED
signatures, GREEN controls and run receipts are in
[REVIEW5.md](../content_restrictions_unit4/REVIEW5.md).

## Unit 4 review 6 evidence refresh at `763a20295f0`

The pre-refresh seed-86019 run observed **2 examples, 1 failure**: exactly two
stale assertions at `moderation.rb:714` and `moderation.rb:759`. It did not raise
an `IndexError`. Re-read the current declaration, dispatch body, policy guard
and `78600db48de..763a20295f0` diff before refreshing:

| Source | Evidence moves | Re-review |
| --- | --- | --- |
| `lib/discourse_mcp/tools/moderation.rb` | `PerformReviewableAction` 714 → 719; `reviewable.perform` 759 → 764 | The preceding PM-off refusal for `revise_and_reject_post` adds five lines. Scoped lookup, authored/stored-text checks, stored-topic transaction and permitted native dispatch remain. Fixed system notices to a poster do not violate invariant 2 when their PM locator is absent from agent output; the revise/reject refusal remains a conservative extra. |

`unit4_review6_refresh` records the two moves and current entry conditions;
earlier review metadata remains historical. All **245 live evidence occurrences**
and graph references were checked twice after refresh. Counts remain **56
operation rows, 55 distinct write primitives, 116 paths and three exclusions**.
Both enrichment examples pass in the final seed-86019 combined run, with no
`IndexError`. Exact example names, calibration limits and RED signatures are recorded in
[REVIEW6.md](../content_restrictions_unit4/REVIEW6.md).

## Unit 5 review 2 evidence refresh at `85c7e890132`

Seed **57219** observed **2 examples, 1 failure** before the refresh: exactly
three stale category evidence assertions, with no `IndexError`. Read the current
method bodies and `9b5114149e3..85c7e890132` before updating:

| Source | Evidence move | Re-review |
| --- | --- | --- |
| `app/models/category.rb` | category_create 638 → 644 | The post build/save in create_category_definition remains the native cooking path after a permitted category save. |
| `app/models/category.rb` | category_update 652 → 658 | revise_category_definition still revises the first post with skip_validations; the native revision/rebake edges remain after a permitted save. |
| `app/models/category.rb` | category_events 1230 → 1236 | The three category event methods still dispatch DiscourseEvent.trigger; downstream listener edges remain after permitted mutations. |

Six preceding callback-registration lines account for all three moves. The new
save/destroy guards condition entry; these native bodies and their classifications
are unchanged. `unit5_review2_refresh` records the moves and revision; historical
metadata remains intact.

After refresh, all **245 live evidence occurrences** and graph references were
checked directly. Counts remain **56 operation rows, 55 distinct write primitives,
116 paths and three exclusions**. Both enrichment examples pass in the combined
seed-57219 run, with no `IndexError` (**22 examples, 12 intentional unit 5 regression
failures, zero pending, zero errors outside examples**). Exact new names, RED
signatures, controls, the bulk-import limit and run receipts are recorded in the
[unit 5 review 2 section](../content_restrictions_unit5/README.md#unit-5-review-round-2-at-85c7e890132).

The post-lint full unit 5 + enrichment repeat (seed **57220**) also passed both
enrichment examples without `IndexError`: **87 examples, 12 intentional new unit 5
failures**, all 65 existing unit 5 examples GREEN. A second direct comparison of
all 245 live evidence occurrences and graph references found no mismatch.

## Unit 5 review 3 / unit 6 baseline verification at `6bb68077df8`

Two direct source comparisons of all **245 live exact-line evidence occurrences**
found **zero stale anchors**. Every graph reference resolves; counts remain
**56 operation rows, 55 distinct write primitives, 116 paths and three exclusions**.
No live evidence or historical refresh metadata needed changing, so
`enrichment_inventory.json` is unchanged.

The isolated inventory run, seed **58319**, passed **2 examples, 0 failures**.
The combined unit 5 + unit 6 + inventory run, seed **68320**, also passed both
inventory examples without `IndexError`: **129 examples, 42 intentional new
regression failures**, zero pending and zero errors outside examples. All 85
pre-existing unit 5 examples passed. The new pins and complete per-example RED
inventories are recorded in the [unit 5 README](../content_restrictions_unit5/README.md)
and [unit 6 README](../content_restrictions_unit6/README.md).

Receipts: `/tmp/cr-u6-inventory-58319.json` and
`/tmp/cr-u6-combined-68320.json`. All RSpec invocations used the repo Ruby 4.0.7,
Bundler 4, `LOAD_PLUGINS=1`, and only `RAILS_DB=discourse_test_mcp_content` through
`hc`. No migration or service management was performed.

The final post-lint seed **68321** repeat again passed both inventory examples:
**129 examples, 42 intentional failures**, all 85 existing unit 5 examples GREEN,
zero pending, zero errors outside examples, and no `IndexError`. Receipt:
`/tmp/cr-u6-final-68321.json`. The two source comparisons and both combined run
receipts agree on the unchanged 245 evidence anchors and graph counts.
