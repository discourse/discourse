# MCP content restrictions: review 4 oracle

Baseline: **6bb81ffd3901e7245b70d86eef7ac1abbb06d7a1**. Production code is
unchanged. This is regression coverage for the four accepted round-3 findings,
with the GREEN and unpinned variants distinguished below.

Only these five authorized files change: the new unit-4 `review4_spec.rb`, the
new unit-3 `review4_setting_urls_spec.rb`, this report, and unit-2's inventory
and README. No other specs, implementations or configuration change. No commit,
stash, checkout, reset, amend, push, migration, core-database operation or service
start/stop was performed. Tests use `LOAD_PLUGINS=1`, the dedicated
`RAILS_DB=discourse_test_mcp_content`, repository Ruby **4.0.7**, and Bundler
**4.0.23**, through `hc`.

## Verification and calibration

The calibrated combined run (seed **84019**) executed **42 examples: 27 expected
RED, 15 GREEN, zero pending, zero outside-example errors**, in **22.98 seconds**
(excluding load), exit 1. Its JSON receipt is `/tmp/cr-review4-calibrated.json`.
The final post-lint receipt is recorded at the end of this report.

| File | Examples | RED | GREEN |
| --- | ---: | ---: | ---: |
| New unit-4 review 4 writes | 14 | 7 | 7 |
| New unit-3 review 4 setting URLs | 26 | 20 | 6 |
| Refreshed unit-2 enrichment inventory | 2 | 0 | 2 |

All writes and reads run through the real `DiscourseMcp::Server`, OAuth tokens,
fresh request contexts, and real topic/post/tag/reviewable/rule records. Neither
the content policy nor renderer is mocked. Host configuration probes stub only
existing Discourse hostname/base-URL configuration accessors. No future class,
constant or helper API is assumed.

Fixed IDs use **112840000–112849999**. Before adding the files, searches with
`rg --no-ignore` checked unit 1 (`content_restrictions/`) and units 2–4. A second
recursive scan of existing Ruby/JSON numeric literals, including underscore and
plain spellings, found zero conflicts. Introduced fixed IDs are tags
112840010–013, 020, 030, category 112840100 and topic 112840101. The shared
fixtures retain their existing IDs.

Each denied write first succeeds with no rule inside a rolled-back transaction.
Tag tests assert the exact saved tags; link tests assert the actual cooked href
and label. Active-rule refusal assertions compare the whole existing envelope,
then independently compare all topics/posts (including soft-deleted records),
tag rows, topic-tag joins, and reviewable status/target/topic/payload. A future
output-only refusal still fails the persistence assertion. No blanket rollback
surrounds the active-rule write under test.

Settings first expose the exact URL without a rule, then independently put it
in `value` with an external `default`, and in `default` with an external `value`.
Under the active rule, both fields must be null with `redacted: true`. Every RED
settings example has **four** failures: two field placements times structured
output and decoded JSON text output. The defaults provider is restored in
`ensure`. Both forum-only and PM-only rules run the full matrix.

## Write examples and observed signatures

**W** means HTTP 200 success with `isError: false` instead of the required tool
refusal, a failed full-envelope comparison, and a separate failed persistence
comparison. These are three independently observed assertions in every RED
write example; no setup failure is counted as a RED pin.

| Exact new example name | Observed result at HEAD |
| --- | --- |
| `[cr-u4] refuses a labelled percent_encoded host link to this site without persisting content` | RED W: labelled internal href is accepted; a real topic/post retains the raw and cooked link. |
| `[cr-u4] refuses a labelled trailing_dot host link to this site without persisting content` | RED W: labelled internal href is accepted; a real topic/post retains the raw and cooked link. |
| `[cr-u4] refuses a labelled uppercase host link to this site without persisting content` | GREEN: existing host comparison already refuses it with the exact reference envelope and unchanged state. |
| `[cr-u4] refuses a labelled unicode_site host link to this site without persisting content` | RED W: labelled internal href is accepted; a real topic/post retains the raw and cooked link. |
| `[cr-u4] refuses a labelled punycode_site host link to this site without persisting content` | GREEN: Unicode href cooks to the configured punycode host and is already refused atomically. |
| `[cr-u4] refuses create_topic after category filtering frees a denied watched-tag slot without persisting content` | RED W: success with null post/topic/slug IDs; a real topic, post and kept + denied watched-tag joins persist. |
| `[cr-u4] persists allowed create_topic after category filtering frees an allowed watched-tag slot` | GREEN: real topic/post persist with exactly the kept + allowed watched tags; the category-excluded input tag is absent. |
| `[cr-u4] refuses queued_approval after category filtering frees a denied watched-tag slot without persisting content` | RED W: success with created-post/topic IDs; approval becomes approved and the topic/post/kept + denied watched tags persist. |
| `[cr-u4] persists allowed queued_approval after category filtering frees an allowed watched-tag slot` | GREEN: real topic/post persist with exactly the kept + allowed watched tags; the category-excluded input tag is absent. |
| `[cr-u4] refuses non-staff approval of a non-tagging author's string payload tags without persisting content` | RED W: success with created-post/topic IDs; the non-tagging author’s payload is approved and the denied tag persists with a real topic/post. |
| `[cr-u4] persists non-staff approval of a non-tagging author's allowed string payload tags` | GREEN: the same non-staff reviewer approves the non-tagging author’s topic; real post/topic and exactly the allowed payload tag persist. |
| `[cr-u4] refuses non-staff approval of a non-tagging author's object payload tags without persisting content` | RED W: success with created-post/topic IDs; the non-tagging author’s payload is approved and the denied tag persists with a real topic/post. |
| `[cr-u4] persists non-staff approval of a non-tagging author's allowed object payload tags` | GREEN: the same non-staff reviewer approves the non-tagging author’s topic; real post/topic and exactly the allowed payload tag persist. |
| `[cr-u4] refuses a denied watched-tag private message atomically and persists an allowed watched-tag private message` | GREEN: denied watched-tag PM gets the exact policy refusal with unchanged state; allowed watched-tag PM/post and tag persist. |

The category fixture supplies two allowed-to-policy tags under
`max_tags_per_topic=2`: one retained by the destination category, one restricted
to another category. Saving removes the second before watched-word tagging,
freeing a slot for the denied watched tag. The denied watched tag is a fresh
record after the input tags, rather than the earlier shared denied-tag fixture;
this avoids the unordered lookup selecting it before truncation and hiding the
reported defect. Its allowed sibling watcher exercises the same filtering and
limit with an allowed final tag. The exact required CreateTopic refusal is
calibrated against the missing-category Server response; approval uses the
existing generic policy refusal.

The approval fallback fixture makes both the author and reviewer unable to tag;
the reviewer is a real non-staff category moderator. It checks queue access only
after a reviewable exists. String payloads use `" u4-denied "`, which saving
normalizes to the denied tag; object payloads use `{"name":"u4-denied"}` exactly.
The exact string `"u4-denied"` is already excluded by the queue lookup, so using
only that string would never reach the fallback. Both allowed sibling payload
shapes persist through the same reviewer. The allowed string name is short
enough to survive normal tag cleanup unchanged.

Host writes use labelled Markdown links to the real denied topic. The encoded
host is **review-four-s%69te.example**: encoding the first character instead
caused the real sanitizer to remove href, so that discarded fixture is not a
claimed bypass. The trailing-dot and percent-encoded hrefs survive cooking
unchanged. For a Unicode configured base URL `https://bücher.example`, a labelled
punycode href survives and is accepted on HEAD. The main hostname stays an ASCII
alias for this probe so ordinary logo URL helpers can render; changing every
hostname accessor to Unicode caused an unrelated URI ASCII error. The reverse
probe configures the punycode host and authors the Unicode spelling, which the
renderer already canonicalizes and refuses.

Each host example also persists an ordinary labelled external-link control
under the active rule, with a distinct title so duplicate-title validation cannot
mask the intended host assertion. Preliminary runs exposed that masking and an
overlong allowed whitespace tag; those fixture errors are excluded from the
calibrated counts above.

## Setting URL examples and observed signatures

**U** means the exact `BROWSER LOCAL URL RETAINED in value/default` assertion:
HEAD retains the local URL and the external counterpart instead of the required
null/null/redacted projection. Each RED row independently exhibits U in both
field placements and both response surfaces.

| Exact new example name | Observed result at HEAD |
| --- | --- |
| `[cr-u3] conceals backslash_absolute URL setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals backslash_network URL setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals backslash_short_host URL setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] keeps external absolute URLs and plain non-URL settings under forum_content` | GREEN: external absolute URL value/default and plain title value/default remain visible on both surfaces. |
| `[cr-u3] conceals percent_encoded host setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals trailing_dot host setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals uppercase host setting values and defaults under private_messages` | GREEN: both fields are already concealed in both placements/surfaces. |
| `[cr-u3] conceals unicode_site host setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals punycode_site host setting values and defaults under private_messages` | GREEN: Unicode URL on the punycode-configured site is already concealed in both placements/surfaces. |
| `[cr-u3] conceals bare_relative URL setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals percent_encoded host setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals special_scheme_slash URL setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals special_scheme_relative URL setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals backslash_relative URL setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals backslash_absolute URL setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals backslash_network URL setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] conceals backslash_short_host URL setting values and defaults under private_messages` | RED U (four policy assertion failures). |
| `[cr-u3] keeps external absolute URLs and plain non-URL settings under private_messages` | GREEN: external absolute URL value/default and plain title value/default remain visible on both surfaces. |
| `[cr-u3] conceals trailing_dot host setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals uppercase host setting values and defaults under forum_content` | GREEN: both fields are already concealed in both placements/surfaces. |
| `[cr-u3] conceals unicode_site host setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals punycode_site host setting values and defaults under forum_content` | GREEN: Unicode URL on the punycode-configured site is already concealed in both placements/surfaces. |
| `[cr-u3] conceals bare_relative URL setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals special_scheme_slash URL setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals special_scheme_relative URL setting values and defaults under forum_content` | RED U (four policy assertion failures). |
| `[cr-u3] conceals backslash_relative URL setting values and defaults under forum_content` | RED U (four policy assertion failures). |

Concrete spellings use the real topic 112840101:

| Shape | Stored URL value or default |
| --- | --- |
| `percent_encoded` | `https://review-four-s%69te.example/t/secret/112840101` |
| `trailing_dot` | `https://review-four-site.example./t/secret/112840101` |
| `uppercase` | `https://REVIEW-FOUR-SITE.EXAMPLE/t/secret/112840101` |
| `unicode_site` | `https://xn--bcher-kva.example/t/secret/112840101`, with Unicode configured base URL |
| `punycode_site` | `https://bücher.example/t/secret/112840101`, with punycode configured host |
| `bare_relative` | `t/secret/112840101` in the URL setting `tos_url` |
| `special_scheme_slash` | `https:/t/secret/112840101` |
| `special_scheme_relative` | `https:t/secret/112840101` |
| `backslash_relative` | `BACKSLASHtBACKSLASHsecretBACKSLASH112840101` |
| `backslash_absolute` | `https:BACKSLASHBACKSLASHreview-four-site.exampleBACKSLASHtBACKSLASHsecretBACKSLASH112840101` |
| `backslash_network` | `BACKSLASHBACKSLASHreview-four-site.exampleBACKSLASHtBACKSLASHsecretBACKSLASH112840101` |
| `backslash_short_host` | `BACKSLASHBACKSLASHtBACKSLASHBACKSLASHsecret`, with configured host `t` |

In that table `BACKSLASH` denotes exactly one literal backslash; the specs use
ordinary Ruby string escaping. The short-host fixture deliberately configures
`t`: two leading backslashes introduce an authority, so interpreting that
spelling as local on an arbitrary other host would be an invalid calibration.

Node's standard WHATWG `URL` resolver was run against these exact spellings.
The encoded host resolves to the ASCII site hostname; uppercase resolves to
lowercase; the Unicode/punycode pair resolves to the same ASCII hostname.
Relative, special-scheme and backslash paths resolve to the configured site;
the short-host case resolves to `https://t//secret`. A trailing dot is **retained**
by the resolver, so no same-origin equality claim is made for that spelling.
Its concealment is the requested site-host alias contract. This was a WHATWG
resolution check, not a native-browser navigation or DNS/HTTP hosting test.

## Allowed controls and weaker alternatives

The two category-filtering writer controls persist exactly the kept and allowed
watched tags. The two non-staff approval controls persist exactly the allowed
string/object payload tag. The PM example persists an allowed watched-tag PM
and refuses a denied one atomically. All five are GREEN. External labelled links
persist in every authored-host example. External setting URLs and plain non-URL
titles stay visible under both kinds of rule. Uppercase hosts and the reverse
IDN direction already refuse/conceal correctly and remain GREEN.

The state assertions reject simply hiding IDs or refusing after persistence.
Allowed sibling writes reject banning all topic creation, watched tags,
category-reviewer approvals, non-tagging authors or object-shaped payloads.
Category fixtures preserve a genuine allowed input tag while dropping another,
so empty-tag-only predictions do not satisfy the allowed control. Separate
value/default probes reject checking only one setting field. PM-only settings
reject gating the fix on forum rules. External and plain-title controls reject
redacting all strings or all URLs. No hypothetical weaker production fix was
installed or mutation-tested; these are observed behavioral counterexamples on
unchanged HEAD.

## What could not be pinned RED

**CreatePrivateMessage category-filtering bypass:** its Server schema accepts no
input tags or category, and TopicCreator removes category context for PMs. Thus
there is no first category-filtered input-tag save to free the watched-word slot
through this writer. The real denied-watched-tag PM probe is already GREEN,
including exact envelope and zero persistence; the allowed watched-tag PM also
persists. No RED is claimed for this variant. CreateTopic and queued approval
both reproduce finding 1 independently.

**Uppercase host spellings and reverse IDN direction:** all their authored and
settings probes are already GREEN at HEAD. Percent-encoded, trailing-dot and
Unicode-base/punycode-link cases are RED on both write and settings sides.
The IDN base URL is a configuration probe with real rendered writes, rather than
an actual Unicode DNS deployment. No finite matrix claims every URL spelling.

## Inventory refresh (B)

Before the refresh, the exact-line example failed at `moderation.rb:704`, then
raised IndexError at the out-of-range site-settings line 479 before reaching the
remaining rows. Direct comparison of every live evidence occurrence found four
stale references, re-read in their current source bodies:

| Evidence | Old → HEAD |
| --- | --- |
| `PerformReviewableAction` declaration | moderation 704 → 714 |
| `reviewable.perform` dispatch | moderation 744 → 754 |
| `UpdateSiteSetting` declaration | site_settings 479 → 277 |
| `SiteSettingSupport.update!` call | site_settings 542 → 340 |

The inventory and its README retain historical reviews and add
`unit4_review4_refresh`. Classifications and native graph edges remain unchanged;
notes describe changed MCP entry conditions. All 245 evidence occurrences and
graph references were rechecked directly after the update. Counts remain 56
operation rows, 55 distinct write primitives, 116 paths and three exclusions.
Both enrichment examples are GREEN in the combined run.

## Reproduction

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit4/review4_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/review4_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --seed 84019 --format documentation
```

The first hc launch inherited an older Bundler and exited before loading tests;
subsequent runs explicitly prefix PATH with the installed repository Ruby's bin
directory. This is not a RED test receipt.
