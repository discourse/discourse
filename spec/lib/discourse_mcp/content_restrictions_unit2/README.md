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

Its seventeen examples cover text quality, explicit draft seeds, plugin presence/absence,
schema identifier coverage, strict caller-echo substitution, every plan-based availability row,
both legitimate blocked response envelopes with malformed/extra-content rejection cases, every
canary's normalized title/slug/excerpt forms across all six configurations, isolated response
surfaces with escaped JSON text, and attribution of a single output failure to its matrix cell.
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
