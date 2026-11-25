# MCP content restrictions: review 2 regression pins

## Oracle decisions, 2026-11-25

The implementation under review is uncommitted on HEAD
`cc81b6c5ea250b33751da2851861af27a89a93fa`. Only the two review-2 specs and this
document are amended in this pass.

**CreateTopic effective tags use the missing-category envelope.** The existing
[tag oracle](tags_spec.rb) requires that envelope for denied effective tags
from synonym/parent expansion and watched words. Case, whitespace and truncation
are other ways of reaching the same denied prospective tag set; they do not
justify a different response. The generic policy-blocked reference helper was
the conflicting assertion. Each amended example now compares the whole response
with a real missing-category request, retaining refusal and content atomicity.

**Unjudged event identifiers fail closed.** Route recognition exposes
`controller: "discourse_events/events"` and `id`, while the controller's `show`
action explicitly loads `Events::Event` and authorizes its post. The route
metadata does not establish that model mapping. This oracle does not require a
registration API or a plugin-specific model mapping outside the approved scope:
concealing both event URLs while a rule is active preserves the restriction
boundary. Registration could preserve allowed-event availability, but is not
required for correctness when unknown identifiers are concealed. This is a
decision for this concrete route, not a universal certification of plugin routes.

The amended event example calibrates both event URLs with real HTTP responses
and keeps both visible before the rule. After activation it conceals both, in
relative and absolute form and in both output payloads. A recognized, HTTP-proven
allowed core topic URL remains visible, defeating blanket local-URL redaction.

### Amended examples and retained HEAD RED evidence

RED is re-proved from the existing [baseline receipt](review2_verification.json),
revision `cc81b6c5ea250b33751da2851861af27a89a93fa`, seed **62690**; this pass does
not rerun HEAD or replace any library files. The receipt uses the original names
listed in the historical tables below. The failing assertions identified here
are unchanged in the amended examples, as are their failing request arguments,
fixtures and policies.

| Exact amended example name | Retained RED assertion against HEAD |
| --- | --- |
| [cr-u4] judges case tag names by the tags saving stores and answers like a missing category | `WRITE REFUSAL: expected isError=true` received `isError=false`; `WRITE ATOMICITY: refused reference persisted content` also failed. |
| [cr-u4] judges whitespace tag names by the tags saving stores and answers like a missing category | Same two recorded failures, independently observed for whitespace. |
| [cr-u4] judges truncation tag names by the tags saving stores and answers like a missing category | Same two recorded failures, independently observed for truncation. |
| [cr-u3] conceals unjudged engine event identifiers and keeps an allowed core topic URL | `restricted URL retained: /discourse-post-event/events/104620001.json` and the corresponding absolute URL. The denied-event concealment assertions remain unchanged. |

For the tag examples, the old helper's refusal and state comparisons are now
inline; the missing-category calibration is isolated in a rolled-back
transaction before the state snapshot. Their RED evidence is acceptance and
persistence of denied effective tags, independent of the changed envelope
comparison. For the event example, the original denied-event leak alone still
makes the amended example RED. The new allowed-event concealment assertion was
not itself run against HEAD in this pass; the retained denied-event assertion
supplies the RED proof. The baseline receipt is preserved unchanged.

### Working-tree verification

Both files passed together through `hc`, seed **62690**, with
`LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content` and the installed Ruby
4.0.7 executable first on PATH:

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit4/review2_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/review2_setting_urls_spec.rb \
  --seed 62690 --format documentation
```

Observed: **21 examples, 0 failures**, exit 0; **14** unit-4 examples and **7**
unit-3 examples. Runtime was **14.21 seconds**, plus **3.63 seconds** loading.
All four amended examples passed, including the complete missing-category
envelope comparisons and concealment of both event URLs while keeping the core
topic URL.

The first amended run passed all tag examples but stopped the event example at
an added core-route calibration: Rails returns `id`, not `topic_id`, for this
route. Correcting that fixture assertion produced the final passing run above;
the intermediate failure is not policy RED evidence.

Targeted `bin/lint --fix` through `hc` passed RuboCop (two files, no offenses)
and Syntax Tree before the final test run. The first lint launch used an
incorrect pnpm PATH; the successful invocation used its actual installation
directory. No production files, other specs, baseline receipts, migrations or
services were changed in this pass. No git state-changing commands were used.

## Historical baseline evidence

The remainder records the original oracle run, before the decisions above and
before the current implementation. Its example names, allowed-event control and
RED status are historical; the amended contracts above supersede them.

Baseline: `cc81b6c5ea250b33751da2851861af27a89a93fa`, unchanged throughout.
New files: [unit 4 examples](review2_spec.rb) and
[unit 3 URL examples](../content_restrictions_unit3/review2_setting_urls_spec.rb).
[Assertion receipts](review2_verification.json) preserve each example's observed
failure messages, the command, seed and inventory baseline. Production code was
not edited.

The final combined run, seed **62690**, executed **23 examples: 21 expected RED,
two GREEN inventory examples**, zero pending and zero errors outside examples.
All 21 new examples failed at the intended policy assertions, after their
renderer, persistence or real HTTP destination calibrations passed.

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit4/review2_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/review2_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb
```

Tests ran through `hc`, with installed Ruby **4.0.7** / Bundler **4.0.23** and
`LOAD_PLUGINS=1`, against **discourse_test_mcp_content** only. The first hc
launch inherited an older Bundler and stopped before running examples; later
launches supplied the installed Ruby path. No database migrations or service
changes were performed.

## New unit 4 examples and observed RED

Every name below includes the `[cr-u4]` prefix in the spec.

**R** means the assertion `WRITE REFUSAL: expected isError=true` received
`isError=false`, and the separate `WRITE ATOMICITY: refused reference persisted
content` assertion also failed. This pins acceptance and the write itself,
including cases where returned topic/post IDs were merely redacted to null.

**A** means `MCP SUCCESS tool error` failed because a required allowed write
received `isError=true`, with `This capability is turned off by the site's AI
content restrictions`. The unrestricted renderer calibration had already passed.

| Exact example name after prefix | RED signature and calibration |
| --- | --- |
| refuses mention names containing browser path traversal | R; stored `/u/../t/101620001` and its matching `@../t/101620001` text survive cooking; normalized destination is the restricted topic. |
| refuses mention-group names containing browser path traversal | R; same calibration through `/groups/../t/101620001`. |
| refuses emoji path traversal ../.. | R; cooked `src` retains the traversal; normalized destination is `/uploads/review-two.png`. |
| refuses emoji path traversal %2e%2e/%2e%2e | R; encoded dots survive cooking and resolve outside the emoji directory after decoding. |
| keeps rendered configured emoji on an overlapping internal host | A; `:seedling:` really renders under the configured `/custom-emoji` base on the site host. |
| keeps rendered configured emoji on an overlapping cdn host | A; same real renderer control on a configured CDN host. |
| keeps genuine granted attachments rendered from upload short URLs | A; genuine attachment markdown using `upload://` really renders to the granted upload's `short_path`; decoding that path returns its SHA1. |
| refuses a granted attachment decoy whose href names topic | R; cooked `data-orig-href` names the grant, but the independent `href` names an internal topic. |
| refuses a granted attachment decoy whose href names other_upload | R; cooked `href` names a different, ungranted upload. |
| judges case tag names by the tags saving stores | R; uppercase input matches a long stored tag and saving also adds its cleaned, truncated denied prefix. Unrestricted persisted tags must be exactly those two records. |
| judges whitespace tag names by the tags saving stores | R; surrounding whitespace prevents the initial stored-name match during saving; the actual saved tag is exactly the truncated denied tag. |
| judges truncation tag names by the tags saving stores | R; reducing `max_tag_length` to eight lands on a different denied tag as well as the long stored tag. |
| judges queued hash tags without_id by saving and keeps allowed hash tags | R; real approval stores the long tag plus its denied truncated prefix. A separate allowed hash-tag approval succeeds first. |
| judges queued hash tags with_id by saving and keeps allowed hash tags | R; same persisted result with an ID in the queued payload; the real queue's saving path uses the hash's name. The allowed hash with an ID also succeeds first. |

These are new examples, not revisions to review 1 or its fixtures. Explicit IDs
use fresh `101_620_...` through `104_620_...` ranges. Shared setup uses its existing
fabricators and does not introduce any reused fixed fixture IDs.

## New unit 3 examples and observed RED

Every name below includes the `[cr-u3]` prefix. Each URL is checked in both
structured and text JSON output, in relative and absolute form.

| Exact example name after prefix | Observed assertion failure |
| --- | --- |
| uses full query permalink identity for restricted destinations | `restricted URL retained: /review-two-query?view=seasonal`; the response keeps the URL instead of null value/default and `redacted=true`. A real HTTP 301 proves the query URL targets the denied topic while the queryless decoy targets the allowed topic. |
| uses full query permalink identity for allowed destinations | `allowed URL redacted: /review-two-query?view=seasonal`; actual value is null and redacted is true. Real HTTP proves the opposite target assignment. |
| gives a live restricted route precedence over a conflicting permalink | `restricted URL retained: /t/103620001.json`; HTTP 200 JSON identifies the live denied topic despite a same-path permalink to an allowed topic. |
| gives a live allowed route precedence over a conflicting permalink | `allowed URL redacted: /t/103620002.json`; HTTP 200 identifies the live allowed topic despite a permalink to a denied topic. |
| follows query-sensitive permalink chains and keeps allowed chains | Both `restricted URL retained: /review-two-chain-start/0` and `allowed URL redacted: /review-two-chain-start/1`. Real HTTP 301s calibrate both hops, with queryless decoys pointing the opposite way. |
| conceals topic external identifiers and keeps allowed topics and user profiles | `restricted URL retained: /t/external_id/review-two-denied`; actual HTTP redirects identify the corresponding topics. The allowed external-ID URL and a user-profile URL remain visible. |
| conceals engine event identifiers whose posts are restricted and keeps allowed events | `restricted URL retained: /discourse-post-event/events/104620001.json`; the engine recognizes its event ID, and real HTTP 200 JSON identifies the event whose post belongs to the denied topic. The allowed event URL remains visible. |

The receipt includes the corresponding absolute-URL failures. Recognition and
HTTP calibration assertions pass before any redaction assertion fails; these
are not failures caused by missing plugin setup or nonexistent records.

## Allowed controls and weaker implementations

The final run observed these controls passing before the paired RED assertions:

- Genuine user and group mentions, rendered from ordinary mention syntax.
- Ordinary site emoji, rendered from `:seedling:`.
- Genuine granted full-URL attachments, rendered from attachment markdown,
  with the expected href and no forged `data-orig-href`.
- Queued topics with allowed hash-form tags, both with and without IDs; each
  approval persists exactly the allowed tag and reaches approved status.
- Allowed topic external-ID URLs, engine event URLs and user-profile URLs.
- Every query/precedence URL remains visible before activating a rule.

Configured emoji on overlapping hosts and genuine short-URL attachments are
also required allowed controls, but are **RED today**, separately pinned above.
The attachment short-URL example was added after real renderer calibration
showed that the normal `upload://` syntax produces `/uploads/short-url/...`,
not a full upload URL or a `data-orig-href` attribute. The full-URL control stays
GREEN and the forged-anchor examples reach their refusal assertions.

The controls defeat blanket refusals of mentions, emoji, upload links, hash
payloads or local URLs. Exact persisted tag sets defeat a preview that only
matches stored names case-insensitively or strips whitespace. Opposite target
assignments defeat path-only permalink lookup and unconditional permalink
precedence. The allowed profile defeats treating every route's `id` as a topic
or post identifier. No production mutation checks were attempted because this
handoff is restricted to test/document edits.

During fixture development, adding allowed topic writes with the same title
caused duplicate-title validation to obscure four refusal signatures. Distinct
control titles removed that interference; the final receipt shows the intended
`isError=false` and atomicity failures for all four traversal cases. Intermediate
fixture failures are not counted as pins.

## Declined `/faq` and `/guidelines`

I agree with the declined disposition under the stated boundary. In the current
routes these are `static#show` with static page names, not record identifiers.
`StaticController::DEFAULT_PAGES` obtains the destination from `faq_url` and
`guidelines_topic_id`; `/guidelines` uses the FAQ topic mapping. The setting
projection checks local URLs and existing `_topic_id` references under an active
policy. A page alias therefore does not itself disclose a specific record
locator. No examples requiring concealment of those aliases were added.

## Remaining non-test gate

No accepted concrete case remains unpinned. These examples establish one real
engine route's semantics; they cannot prove that every present or future plugin
route's opaque identifier is classified. That universal claim needs a route
coverage/registration review or an equivalent implementation gate that refuses
unjudged content identifiers while retaining non-governed records. Arbitrary
plugin handlers and redirects cannot be certified by this finite example set.

The tests also establish HTTP destinations and URL normalization, not a native
browser navigation pass. Browser-equivalent dot-segment resolution is explicit
in the fixtures; no claim of browser UI testing is made.

## Inventory and lint

Before refresh, seed **28553** observed the exact-line example fail at four
locations: `private_messages.rb:302/341` and `moderation.rb:683/723`. Each current
body and the intervening diff were re-reviewed. Live evidence now points to
**310/349** and **702/742**, respectively. The unit 2 README table and inventory
review metadata record the changed PM creation and queued approval gates.

After refresh, both enrichment examples passed in the final combined run.
All **245** live evidence occurrences and graph references were also checked
directly, twice; counts remain **56 operations, 55 distinct primitives, 116 paths,
three exclusions**.

`bin/lint --fix` passed RuboCop (two files, no offenses) and Syntax Tree for both
new Ruby files. The successful hc invocation supplied installed Ruby/Node/pnpm
paths after the initial lint invocation lacked pnpm. The formatter ran after the
recorded regression run and only changed layout. JSON and Markdown have no
applicable core linter here; JSON was parsed and `git diff --check` passed.
