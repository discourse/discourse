# Unit 4 write rules: adversarial review 1 oracle

Verified against unchanged HEAD `ec0c8a3ac5220774053fd6f787f1860553b34d5e`.
The new [review1_spec.rb](review1_spec.rb) adds **28 examples tagged `[cr-u4]`**:
**22 observed RED regressions for all eight accepted findings**, plus **six GREEN
allowed controls**. All **227 existing unit 4 examples** and both unit 2 enrichment
examples pass in the same run: **257 examples, 22 failures, 0 pending, 0 errors
outside examples**, seed **7702**, 81.130275 seconds excluding loading.

Every RED below passed its fixture setup and unrestricted calibration and reached
an MCP-response or persisted-state assertion. No implementation was substituted,
patched or mocked. Existing support supplies the MCP call and canonical ungranted
upload refusal. The negative cases require that complete identical response,
including status, headers, content, error flag and absence of structured content,
and preserve the existing persisted-content snapshot. Tag-group names have an
additional explicit TagGroup snapshot because content_state does not cover them.
The new missing-topic fixture uses `99_620_001`; no pre-existing fixed fixture ID
was reused.

## New example names and observed RED signatures

Each table entry is an exact expanded RSpec example name. Signature abbreviations
refer to these observed assertion messages, not anticipated failures:

- **R**: `WRITE REFUSAL: expected isError=true`, actual HTTP 200 and
  `isError=false`, with successful structured content.
- **A**: `WRITE ATOMICITY: refused reference persisted content`; the persisted
  snapshot changes as described in the corresponding row.
- **G**: `TAG GROUP ATOMICITY: refused display name persisted`.
- **E**: `REFERENCE ERROR: rejected forms must have one identical envelope`.
  The PM response is HTTP 200 with `isError=true` and no structured content, but
  its text is `The operation could not be completed with these parameters` instead
  of the canonical ungranted refusal, `This capability is turned off by the site's
  AI content restrictions`. The independent **A** assertion proves the denied-tag
  PM was actually stored; the output refusal alone does not protect the write.

| Finding | New example name | Observed RED signature and persisted result |
| --- | --- | --- |
| 1 | [cr-u4] refuses forged mention anchors to allowed internal destinations | **R + A** — Forged anchor href survives in a newly persisted post. |
| 1 | [cr-u4] refuses forged mention anchors to restricted internal destinations | **R + A** — Forged anchor href survives in a newly persisted post. |
| 1 | [cr-u4] refuses forged mention anchors to missing internal destinations | **R + A** — Forged anchor href survives in a newly persisted post. |
| 1 | [cr-u4] refuses forged mention-group anchors to allowed internal destinations | **R + A** — Forged anchor href survives in a newly persisted post. |
| 1 | [cr-u4] refuses forged mention-group anchors to restricted internal destinations | **R + A** — Forged anchor href survives in a newly persisted post. |
| 1 | [cr-u4] refuses forged mention-group anchors to missing internal destinations | **R + A** — Forged anchor href survives in a newly persisted post. |
| 2 | [cr-u4] refuses ungranted media carried by video attributes before a later rebake | **R + A** — Post persists with the ungranted media attribute. |
| 2 | [cr-u4] refuses ungranted media carried by blocked_src attributes before a later rebake | **R + A** — Post persists with the ungranted media attribute. |
| 2 | [cr-u4] refuses ungranted media carried by blocked_srcset attributes before a later rebake | **R + A** — Post persists with the ungranted media attribute. |
| 3 | [cr-u4] refuses an external emoji-class image even with a site emoji path | **R + A** — Post persists with the external emoji-class image. |
| 4 | [cr-u4] refuses a granted data-orig-src decoy hiding an external real source | **R + A** — Post persists with both the ungranted real src and granted decoy. |
| 4 | [cr-u4] refuses a granted data-orig-src decoy hiding an ungranted_upload real source | **R + A** — Post persists with both the ungranted real src and granted decoy. |
| 5 | [cr-u4] checks stored raw before approve_post_closed publishes a queued reply | **R + A** — Queued reply is published and reviewable becomes approved. |
| 6 | [cr-u4] refuses a new PM whose watched words add a denied tag | **E + A** — Refusal is returned after the PM, first post and denied tag persist. |
| 6 | [cr-u4] refuses queued topic approval made restricted by payload_category | **R + A** — Approval succeeds; restricted topic, first post and approved reviewable persist. |
| 6 | [cr-u4] refuses queued topic approval made restricted by hash_tags | **R + A** — Approval succeeds; restricted topic, first post and approved reviewable persist. |
| 6 | [cr-u4] refuses queued topic approval made restricted by parent | **R + A** — Approval succeeds; restricted topic, first post and approved reviewable persist. |
| 6 | [cr-u4] refuses queued topic approval made restricted by watched_word | **R + A** — Approval succeeds; restricted topic, first post and approved reviewable persist. |
| 7 | [cr-u4] revokes a grant after a synchronous different_user callback writes an unrelated reference | **R + A** — After the unrelated callback reference, a later MCP write reuses the upload and persists. |
| 7 | [cr-u4] revokes a grant after a synchronous same_user callback writes an unrelated reference | **R + A** — After the unrelated callback reference, a later MCP write reuses the upload and persists. |
| 8 | [cr-u4] refuses authored references in create tag-group display names under a PM-only rule | **R + G** — The URL display name is persisted by tag-group creation. |
| 8 | [cr-u4] refuses authored references in update tag-group display names under a PM-only rule | **R + G** — The URL display name is persisted by tag-group update. |

The renderer calibrations check actual persisted cooked output. For blocked src
and srcset, the unrestricted calibration also changes block_hotlinked_media to
false and rebakes the stored post, verifying that the real media attribute becomes
exposed. The blocked srcset starts with a genuinely granted upload and ends with
ungranted external media. The queued-category case has no category column value:
its payload category is the restricted category. The hash-tags case uses the
native supported payload shape `[{ "name": denied_tag.name }]`. The parent and
watched-word cases verify the effective denied tag after unrestricted approval.

The two callback cases register a synchronous native post_created listener. It
creates another post in the same topic, referencing the same upload, through
PostCreator with skip_events to avoid recursion. One author differs from the MCP
user; the other is the same user. Both verify two distinct persisted post references
before attempting later MCP reuse. The listener is removed in ensure. No assertion
reads grant internals or calls their recording/validation methods directly.

## Allowed controls

All these exact new examples are GREEN in the final complete-suite run:

| New example name | Observed result |
| --- | --- |
| [cr-u4] permits genuine user and group mentions and real site emoji | GREEN |
| [cr-u4] permits granted upload images and renderer placeholders through repeated MCP writes | GREEN |
| [cr-u4] permits approve_post_closed with ordinary stored prose | GREEN |
| [cr-u4] permits a PM and queued new topic whose effective tags stay allowed | GREEN |
| [cr-u4] permits a plain create tag-group display name under a PM-only rule | GREEN |
| [cr-u4] permits a plain update tag-group display name under a PM-only rule | GREEN |

These controls verify persisted raw/cooked content, actual mention destinations,
site emoji, upload references, approved reviewables, effective allowed parent and
watched-word tags, and stored tag-group names. Repeated upload writes include both
a normal granted image and a legitimate transparent renderer placeholder carrying
the granted data-orig-src. This prevents a blanket ban on that attribute from
satisfying the decoy examples. The allowed PM and queued-topic control exercises
watched-word and required-parent expansion rather than only empty tag lists.
The same-user callback and granted-first srcset fixtures distinguish owner-only
adoption and first-member-only checking from the required behavior. Candidate
production mutations were not run because implementation edits are prohibited.

## Run receipts

All RSpec runs used hc, the installed Ruby 4.0.7 bin first on PATH, Bundler 4,
LOAD_PLUGINS=1 and only RAILS_DB=discourse_test_mcp_content. No migrations or service
start/stop commands were run.

Final command, hc terminal t78:

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit4/ \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --format json --out /tmp/cr-u4-review1-final.json
```

Final oracle source SHA-256: `c7aae6321249ef8f9e291fc4a9b816589054cda4ec0a3e650f5de5fe6a0c03e4`.
Raw final JSON SHA-256: `c9b884c00bb6f1d071316d4fa4249fc87e9a49ffdce638960cd8e85df2197722`.

The independent pre-final run (t75, seed 65085,
/tmp/cr-u4-review1-third.json) also observed 22 new assertion-level REDs, six GREEN
controls and two passing enrichment examples. The final run additionally includes
the stronger granted-first blocked-srcset fixture, renderer-placeholder control,
explicit missing-ID check, formatting, and all 227 existing unit 4 examples.
Earlier fixture-only failures (status integer versus enum string, group mention
route and srcset spacing) were corrected before these receipts; they are not
counted as regression evidence.

The PM regression additionally exposes an existing diagnostic-rendering problem:
the content-policy tripwire logs an exception without a backtrace, and the RSpec
failure reporter then appends `undefined method 'each' for nil`. The JSON contains
the primary **E + A** assertion failures before that after-hook error. This is not
a setup failure, and no tripwire or logging behavior was stubbed or disabled.

Targeted bin/lint --fix passed via hc t77: RuboCop inspected the new Ruby file with
no offenses and Syntax Tree formatted it. The repository reports no core linter
for these spec-directory JSON/Markdown files. JSON parsing, all 245 live inventory
evidence occurrences, and git diff --check were checked separately.

## Item B: unit 2 evidence refresh

The initial combined run (t73, seed 10601,
/tmp/cr-u4-review1-first.txt) observed the exact-line enrichment example fail at
site_settings.rb:327 and site_settings.rb:390. Both current source bodies and the
ec0c8a3ac52 diff were re-read before changing the evidence:

| Source | Previous line | Verified current line | Re-review |
| --- | --- | --- | --- |
| lib/discourse_mcp/tools/site_settings.rb, class UpdateSiteSetting | 327 | 411 | Preceding read-side URL resolution adds 84 lines. Write declarations, checks and update/verification flow remain. |
| lib/discourse_mcp/tools/site_settings.rb, SiteSettingSupport.update! call | 390 | 474 | Same 84-line movement; the shared helper still invokes SiteSetting::Update. Native setting hooks and rebake edges retain their classification. |

The live inventory entries now use 411 and 474, with per-row
unit4_review1_refresh notes. Historical move records remain historical. The
[unit 2 README](../content_restrictions_unit2/README.md) has the matching refresh
table. Both enrichment examples pass after the refresh, including every one of
the 245 live exact-line evidence occurrences.

## What remains unpinned / needs a non-test gate

**None of the eight accepted findings remains unpinned.** These are deterministic
native-path regressions. They do not establish coverage for arbitrary plugin
publishing actions, future renderer carriers or true cross-process races; those
still require a source review when the paired implementation changes. The
callback tests specifically prove adoption during a synchronous MCP write for
both authors, without claiming to exercise scheduling-dependent races. The
production fix and its GREEN run remain the paired implementer's next step.
