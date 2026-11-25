# MCP content restrictions: review 3 oracle

Baseline: `7d1edac2d9ba44f789a039beedcd4a95809ff3a5` throughout. Production
code is unchanged. This record supersedes the setting-URL availability decisions
in REVIEW1/REVIEW2 and the historical unit-3 reports.

## Design decision

Accept the proposed `redact_internal_urls` boundary. While **any** content rule
is active, a local URL in either a setting's value or default conceals **both**
fields (`value: null`, `default: null`, `redacted: true`). Local includes relative
paths, the current site host, the distinct host/path in `base_url`, configured
CDN, S3 CDN, and external upload-store hosts. External URLs and plain non-URL
values remain readable.

HEAD's `tools/site_settings.rb` recognizes routes, follows redirects/permalinks,
infers models from controller/parameter names, and selectively judges numeric
identifiers. Those mechanisms do not define the controller's behavior:

- `ApplicationController` can resolve a permalink during NotFound handling,
  after a recognized topic route fails (`/t/legacy`).
- `PostLocalizationsController#show` uses its `id` as a **post ID**, rather than
  a PostLocalization primary key.
- `PublishedPagesController#show` finds a page by `slug`, then reads its topic.
- Topic lookup can cast a value such as `111730101anything` to a numeric ID.
- Static page IDs are names with behavior determined by site configuration.

The new oracle judges the URL's internal origin/path, without requiring any
particular routing/model resolver. No new production class, constant, or helper
API is assumed. Configured internal hosts follow the boundary read in
`authored_text.rb`, rather than only the web app's primary hostname.

The availability cost is **accepted**: allowed public topics, allowed categories
and tags, profiles, allowed permalink chains, `/login`, and the static aliases
are concealed too. `/login` is explicitly required to be concealed. On this HEAD
it is already concealed; its examples are GREEN controls of the new contract,
not invented RED evidence. The same distinction applies to static page aliases.

## Scope and calibration

New write pins are in [review3_spec.rb](review3_spec.rb). New URL pins are in
[review3_setting_urls_spec.rb](../content_restrictions_unit3/review3_setting_urls_spec.rb).
All writes/read projections go through `DiscourseMcp::Server` with issued OAuth
tokens and fresh request contexts. Neither the policy nor renderer is stubbed.
The base-URL configuration probe stubs only `Discourse.base_url`; the S3/CDN
probes use existing test configuration helpers.

Fixed IDs use **111730000–111739999**, checked against the existing unit-1
(`content_restrictions/`) and unit-2/3/4 Ruby/JSON fixtures before adding them.
The records actually introduced use 111730001/002, 010–013, 020–022, 030–032, 040,
and 100–103. IDs are independent across topics, posts, tags and uploads.

Each forged-anchor fixture first saves without a rule and checks its real
cooked attributes. Traversal fixtures also decode and normalize the resulting
path to `/t/111730001`. Tag fixtures first perform the real unrestricted save
and check the exact stored tag set. Queued approval calibrates a non-staff
category reviewer who cannot tag, and a queued author who can; the unrestricted
approval saves both child and denied mandatory parent.

New URL cases independently put the local URL in `value` with an external
`default`, then in `default` with an external `value`. Both fields must conceal
in both structured output and decoded text output. The same values/defaults
are first shown readable without a rule; the default provider is restored in
`ensure`. Both forum-only and PM-only rules are exercised.

## Verification

Seed **73019**, `LOAD_PLUGINS=1`, **discourse_test_mcp_content** only, using
`hc` and the repository Ruby/Bundler environment. HEAD stayed at
`7d1edac2d9b`; no implementation fix was applied to obtain RED.

Across the **73 distinct examples**: **54 expected RED, 19 GREEN**, zero
pending, zero outside-example errors. All failures below are intended policy
assertions after the fixture calibrations pass.

| Source | Examples | RED | GREEN |
| --- | ---: | ---: | ---: |
| New unit-4 review 3 | 15 | 12 | 3 |
| New unit-3 review 3 URL specs | 28 | 16 | 12 |
| Amended/renamed existing unit-3 URL examples | 28 | 26 | 2 |
| Refreshed unit-2 inventory | 2 | 0 | 2 |

The combined run executed 69 examples in **80.67 s**, exit 1 for the
50 intended failures. After expanding the attribute-pair matrix and adding the
allowed non-staff reviewer control, the final focused run executed all 15
unit-4 examples and both inventory examples: **17 examples, 12 intended RED,
five GREEN**, **7.86 s**, exit 1. The four added pair cases account exactly for
the increase from 69 to 73 distinct examples and from 50 to 54 RED. Unit-3
specs were unchanged after their combined run. Its allowed external-URL control
covers `https:`, `http:`, and protocol-relative external URLs.

Run the complete current oracle (73 examples):

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit4/review3_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/review3_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/local_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/round3_local_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/review2_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/site_settings_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --seed 73019 --format documentation
```

Raw JSON receipts from this session are `/tmp/cr-review3-final.json` and
`/tmp/cr-review3-u4-pairs.json`; the complete names and decisive evidence are
persisted below so this record does not depend on temporary files.

Targeted `bin/lint --fix` through `hc` passed RuboCop and Syntax Tree for all
six changed Ruby files; the later reviewer-control and attribute-pair edits
also passed both.
The first lint attempt caught a shadowed local variable, which was corrected.
Two preliminary plain-value assertions expected integers where the projection
returns strings; corrected controls are GREEN and those fixture failures are
excluded from the counts. An initial mention fixture tried `data-orig-src`,
which cooking stripped from the anchor; it was removed. The final mention
pins use retained `data-orig-href`, not sanitizer-stripped markup.

## New unit-4 names and RED evidence

**R** means the exact `WRITE REFUSAL: expected isError=true` assertion received
`isError=false`, and a separate content-state comparison proved persistence.
The reference cases also require the complete generic reference-error envelope.
For tags, **M** additionally means the full missing-category envelope comparison
failed; post-write ID redaction did not prevent persistence. The final focused
run observed each row independently.

| Exact example name | HEAD evidence and calibration |
| --- | --- |
| `[cr-u4] judges category-reviewer approval by the queued author's child and mandatory parent tags` | R; HEAD returns success and approves/persists child plus denied mandatory parent. The same non-tagging reviewer successfully approves the allowed child/parent control first. |
| `[cr-u4] judges watched-word tags after synonymous input tags collapse under the tag limit` | R + M; unrestricted save stores the allowed target plus denied watched-word target after two aliases collapse. HEAD returns success with null IDs and persists the denied tag. |
| `[cr-u4] keeps genuine short-url attachments and genuine user and group mentions` | GREEN; stored attachment href is the genuine short path; real user/group mentions have their profile/group hrefs. |
| `[cr-u4] keeps staff approval of an allowed queued topic using staff tag permissions` | GREEN; an admin approves a non-tagging author’s topic and persists exactly the allowed tag. |
| `[cr-u4] keeps synonym-only allowed topics under the tag limit` | GREEN; two aliases save exactly one allowed target under max_tags_per_topic=2. |
| `[cr-u4] refuses mention anchors carrying an ungranted upload in data-orig-href` | R; cooked genuine mention href and ungranted upload in data-orig-href both survive; HEAD accepts and persists the forged anchor. |
| `[cr-u4] refuses mention-group anchors carrying an ungranted upload in data-orig-href` | R; cooked genuine mention href and ungranted upload in data-orig-href both survive; HEAD accepts and persists the forged anchor. |
| `[cr-u4] refuses short-url trailing traversal %2e%2e/%2e%2e/%2e%2e/ in href` | R; cooked short-path href retains trailing dot segments and normalizes to the denied topic; HEAD accepts and persists it. |
| `[cr-u4] refuses short-url trailing traversal %2e%2e/%2e%2e/%2e%2e/ in matching_pair` | R; both cooked href and data-orig-href retain the traversal and normalize to the denied topic; HEAD accepts and persists them. |
| `[cr-u4] refuses short-url trailing traversal %2e%2e/%2e%2e/%2e%2e/ in original` | R; cooked genuine short-path href and traversal data-orig-href both survive; the original normalizes to the denied topic; HEAD accepts and persists it. |
| `[cr-u4] refuses short-url trailing traversal %2e%2e/%2e%2e/%2e%2e/ in pair` | R; cooked short-path href retains trailing dot segments and normalizes to the denied topic; HEAD accepts and persists it. |
| `[cr-u4] refuses short-url trailing traversal ../../../ in href` | R; cooked short-path href retains trailing dot segments and normalizes to the denied topic; HEAD accepts and persists it. |
| `[cr-u4] refuses short-url trailing traversal ../../../ in matching_pair` | R; both cooked href and data-orig-href retain the traversal and normalize to the denied topic; HEAD accepts and persists them. |
| `[cr-u4] refuses short-url trailing traversal ../../../ in original` | R; cooked genuine short-path href and traversal data-orig-href both survive; the original normalizes to the denied topic; HEAD accepts and persists it. |
| `[cr-u4] refuses short-url trailing traversal ../../../ in pair` | R; cooked short-path href retains trailing dot segments and normalizes to the denied topic; HEAD accepts and persists it. |

The traversal matrix covers literal `../../../` and encoded
`%2e%2e/%2e%2e/%2e%2e/`, each as `href` alone, traversal `href` with a genuine
`upload://` original,
genuine short-path `href` with a traversal original, and traversal in both
attributes. Thus validating only `href`, or merely comparing the decoded upload
IDs of the two attributes, cannot satisfy the oracle. The normal attachment
control uses the genuine short-URL rendering path successfully.

The prospective-tag fixture has **two aliases for one target** and a watched
word whose tag resolves to the denied tag, with `max_tags_per_topic=2`.
Saving first collapses the aliases; the watched tag then occupies the free
slot. This distinguishes the intended result from merely truncating the
unresolved names before appending watched tags.

The approval fixture makes the queued author an admin and the reviewer a
non-staff category reviewer with no tagging permission. Its allowed sibling
control persists an allowed child **and mandatory parent** through that same
reviewer. The separate staff control makes the author unable to tag, proving
staff approval must still use staff permissions.

## Existing local-URL controls changed from kept to concealed

Every row marked RED below changed a previously kept local destination to
`value: null`, `default: null`, `redacted: true`. All corresponding inactive-rule
calibrations still keep URLs. No external URL or plain-value control was changed
to concealment. All assertions inspect both output payloads.

### `local_setting_urls_spec.rb`

| Exact current example name | Previously kept control now concealed | HEAD result |
| --- | --- | --- |
| `[cr-u3] ListSiteSettings conceals absolute and relative category routes under forum_content` | Allowed category slug/id routes. | RED: retained `/c/amazing-category-48/91310002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative tag routes under forum_content` | Allowed `/tag/` and `/tags/` routes. | RED: retained `/tag/cru3-route-allowed` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative topic and post routes under forum_content` | Allowed topic/post routes, including short `/p/`, slugged and numeric topic/post forms. | RED: retained `/p/62075` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative topic and post routes under private_messages` | Allowed topic/post routes, including short `/p/`, slugged and numeric topic/post forms. | RED: retained `/p/62081` instead of the null/null/redacted projection. |

### `round3_local_setting_urls_spec.rb`

| Exact current example name | Previously kept control now concealed | HEAD result |
| --- | --- | --- |
| `[cr-u3] ListSiteSettings conceals absolute and relative category edit URLs under forum_content` | Allowed category action URL. | RED: retained `/c/amazing-category-16/edit` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative category find_by_slug URLs under forum_content` | Allowed category action URL. | RED: retained `/c/amazing-category-11/find_by_slug` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative category show URLs under forum_content` | Allowed category action URL. | RED: retained `/c/94510002/show` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative nested_topics URLs under forum_content` | Allowed topic counterpart for the named raw/posts-by-number/nested route. | RED: retained `/n/this-is-a-test-topic-1/95510002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative nested_topics URLs under private_messages` | Allowed topic counterpart for the named raw/posts-by-number/nested route. | RED: retained `/n/this-is-a-test-topic-12/95510002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative numeric tag name fallback URLs under forum_content` | Allowed numeric tag-name fallback. | RED: retained `/tag/98510002.json` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative permalink URLs by their restricted target under forum_content` | Allowed topic/post permalinks; also allowed category/tag permalinks under forum_content. | RED: retained `/cru3-r3-archive/0/1` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative permalink URLs by their restricted target under private_messages` | Allowed topic/post permalinks; also allowed category/tag permalinks under forum_content. | RED: retained `/cru3-r3-archive/0/1` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative posts/by_number URLs under forum_content` | Allowed topic counterpart for the named raw/posts-by-number/nested route. | RED: retained `/posts/by_number/95510002/2` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative posts/by_number URLs under private_messages` | Allowed topic counterpart for the named raw/posts-by-number/nested route. | RED: retained `/posts/by_number/95510002/2` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative raw URLs under forum_content` | Allowed topic counterpart for the named raw/posts-by-number/nested route. | RED: retained `/raw/95510002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative raw URLs under private_messages` | Allowed topic counterpart for the named raw/posts-by-number/nested route. | RED: retained `/raw/95510002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative redirect route URLs by their restricted destination under forum_content` | Redirect route to an allowed category. | RED: retained `/category/amazing-category-9/94510002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative renamed tag id redirect URLs under forum_content` | Allowed renamed-tag ID redirect. | RED: retained `/tags/retired-allowed/97510002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative unrecognized local URLs under forum_content and recognized allowed URLs` | Recognized allowed topic URL paired with the unrecognized path. | RED: retained `/t/this-is-a-test-topic-17/95510002` instead of the null/null/redacted projection. |
| `[cr-u3] ListSiteSettings conceals absolute and relative unrecognized local URLs under private_messages and recognized allowed URLs` | Recognized allowed topic URL paired with the unrecognized path. | RED: retained `/t/this-is-a-test-topic-10/95510002` instead of the null/null/redacted projection. |

### `site_settings_spec.rb`

| Exact current example name | Previously kept control now concealed | HEAD result |
| --- | --- | --- |
| `[cr-u3] ListSiteSettings conceals personal-message URLs with only private_messages active and conceals public URLs` | Public topic URL under a PM-only rule. | RED: public_response still contains the public topic URL as value, with default="" instead of null/null/redacted. |

### `review2_setting_urls_spec.rb`

| Exact current example name | Previously kept control now concealed | HEAD result |
| --- | --- | --- |
| `[cr-u3] conceals a live allowed route with a conflicting permalink` | Live allowed topic route despite a conflicting denied-topic permalink. | RED: retained `/t/103620002.json` instead of the null/null/redacted projection. |
| `[cr-u3] conceals a live restricted route with a conflicting permalink` | None; only renamed for the broader contract. Its restricted-destination concealment assertion is retained. | GREEN; no HEAD RED is claimed. |
| `[cr-u3] conceals full query permalink URLs for allowed destinations` | Permalink whose full query identifies an allowed topic. | RED: retained `/review-two-query?view=seasonal` instead of the null/null/redacted projection. |
| `[cr-u3] conceals full query permalink URLs for restricted destinations` | None; only renamed for the broader contract. Its restricted-destination concealment assertion is retained. | GREEN; no HEAD RED is claimed. |
| `[cr-u3] conceals query-sensitive permalink chains including allowed chains` | Query-sensitive chain ending at the allowed topic. | RED: retained `/review-two-chain-start/1` instead of the null/null/redacted projection. |
| `[cr-u3] conceals topic external identifiers including allowed topics and user profiles` | Allowed topic external-ID URL **and** user-profile URL. | RED: retained `/u/anne32` instead of the null/null/redacted projection. |
| `[cr-u3] conceals unjudged engine event identifiers and an allowed core topic URL` | Allowed core topic URL paired with the already-concealed engine event URLs. | RED: retained `/t/103620002.json` instead of the null/null/redacted projection. |

## New unit-3 URL names and per-example evidence

For each RED row, HEAD returned the shown local URL in both **value-only** and
**default-only** probes instead of concealing both fields. Relative/root-relative
and absolute forms are checked for route cases; host cases check both an
explicit scheme (where supplied by the configuration) and protocol-relative
form. **U** denotes the exact `LOCAL URL RETAINED in value/default` failure.
GREEN rows are required controls; they are not counted as RED.

| Exact example name | HEAD evidence |
| --- | --- |
| `[cr-u3] conceals base_url host setting values and defaults under forum_content` | GREEN: these own-site host URLs already conceal in both field probes. |
| `[cr-u3] conceals base_url host setting values and defaults under private_messages` | GREEN: these own-site host URLs already conceal in both field probes. |
| `[cr-u3] conceals cast_topic_id setting values and defaults under forum_content` | RED U: `/t/111730101anything` retained in both field probes. |
| `[cr-u3] conceals cast_topic_id setting values and defaults under private_messages` | RED U: `/t/111730101anything` retained in both field probes. |
| `[cr-u3] conceals cdn host setting values and defaults under forum_content` | RED U: `https://review-three-cdn.example/garden-reference` retained in both field probes. |
| `[cr-u3] conceals cdn host setting values and defaults under private_messages` | RED U: `https://review-three-cdn.example/garden-reference` retained in both field probes. |
| `[cr-u3] conceals current_hostname host setting values and defaults under forum_content` | GREEN: these own-site host URLs already conceal in both field probes. |
| `[cr-u3] conceals current_hostname host setting values and defaults under private_messages` | GREEN: these own-site host URLs already conceal in both field probes. |
| `[cr-u3] conceals login setting values and defaults under forum_content` | GREEN: /login already conceals in both field probes; availability cost explicitly accepted. |
| `[cr-u3] conceals login setting values and defaults under private_messages` | GREEN: /login already conceals in both field probes; availability cost explicitly accepted. |
| `[cr-u3] conceals not_found_permalink setting values and defaults under forum_content` | RED U: `/t/legacy` retained in both field probes. |
| `[cr-u3] conceals not_found_permalink setting values and defaults under private_messages` | RED U: `/t/legacy` retained in both field probes. |
| `[cr-u3] conceals post_localizations setting values and defaults under forum_content` | RED U: `/post_localizations/111730102.json` retained in both field probes. |
| `[cr-u3] conceals post_localizations setting values and defaults under private_messages` | RED U: `/post_localizations/111730102.json` retained in both field probes. |
| `[cr-u3] conceals published_slug setting values and defaults under forum_content` | RED U: `/pub/review-three-seasonal` retained in both field probes. |
| `[cr-u3] conceals published_slug setting values and defaults under private_messages` | RED U: `/pub/review-three-seasonal` retained in both field probes. |
| `[cr-u3] conceals relative_paths setting values and defaults under forum_content` | RED U: `./login` retained in both field probes. |
| `[cr-u3] conceals relative_paths setting values and defaults under private_messages` | RED U: `./login` retained in both field probes. |
| `[cr-u3] conceals s3_cdn host setting values and defaults under forum_content` | RED U: `https://review-three-uploads.example/garden-reference` retained in both field probes. |
| `[cr-u3] conceals s3_cdn host setting values and defaults under private_messages` | RED U: `https://review-three-uploads.example/garden-reference` retained in both field probes. |
| `[cr-u3] conceals static_pages setting values and defaults under forum_content` | GREEN: /faq, /guidelines, /rules, /conduct, /tos, /privacy already conceal in both field probes. |
| `[cr-u3] conceals static_pages setting values and defaults under private_messages` | GREEN: /faq, /guidelines, /rules, /conduct, /tos, /privacy already conceal in both field probes. |
| `[cr-u3] conceals upload_store host setting values and defaults under forum_content` | RED U: `//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/garden-reference` retained in both field probes. |
| `[cr-u3] conceals upload_store host setting values and defaults under private_messages` | RED U: `//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/garden-reference` retained in both field probes. |
| `[cr-u3] keeps external URL values and defaults under forum_content` | GREEN: HTTP, HTTPS and protocol-relative external value/default remain readable. |
| `[cr-u3] keeps external URL values and defaults under private_messages` | GREEN: HTTP, HTTPS and protocol-relative external value/default remain readable. |
| `[cr-u3] keeps plain non-URL setting values and defaults under forum_content` | GREEN: plain title and numeric max_tags_per_topic value/default remain readable. |
| `[cr-u3] keeps plain non-URL setting values and defaults under private_messages` | GREEN: plain title and numeric max_tags_per_topic value/default remain readable. |

The NotFound-permalink fixture uses `/t/legacy` with a real permalink to the
denied topic and no topic with slug `legacy`. The localization fixture's post
ID is **111730102**; its localization ID is **111730103**, and no localization
has the post ID. The published-page fixture has a real page slug pointing to
the denied topic. The cast fixture checks actual lookup of `111730101anything`
as the denied topic and also includes the literal `/t/456anything`. Static
aliases point at configured denied topics; their current concealment is retained.
Under a PM-only rule these public records are also concealed by the new origin
boundary, independently of their topic policy status.

## Allowed controls and weaker implementations

All four requested allowed controls are GREEN: genuine granted short-URL
attachment; genuine user/group mentions; synonym-only allowed topic; staff
approval of an allowed queued topic. The additional allowed non-staff reviewer
control is GREEN before its paired denied-parent assertion. External URL and
non-URL value/default controls pass under both rule kinds. Every local URL
remains readable in its inactive-rule calibration.

These checks reject blanket bans on attachments, mentions, synonyms, queued
approvals, category reviewers, all URLs, or all slash-prefixed URLs. The two
aliases plus watched-word slot test the collapse/limit ordering, rather than
one-tag-only expansion. The approval controls distinguish reviewer permissions,
author permissions and staff override. Value-only/default-only probes reject
checking only one field, and PM-only cases reject limiting concealment to forum
rules. No production mutation was made to test a hypothetical weaker fix;
these are explicit behavioral counterexamples, not a claimed mutation run.

## Inventory refresh (B)

Before refresh, the exact-line example failed at all four requested locations:
moderation **702/742** and site settings **411/474**. Re-reading the current
source established **704/744** and **479/542**, respectively. The JSON updates
only these four live evidence locations and corresponding review metadata;
older refresh metadata remains historical. The unit-2 README records the moves.
All **245 live evidence occurrences** and graph references were checked twice
directly. Both inventory examples pass in the combined and focused runs:
56 operation rows, 55 distinct write primitives, 116 paths, three exclusions.

## Unpinned cases and limits

No accepted finding remains unpinned. Findings 5–9 are covered by the replacement
origin-based contract; the five shapes are NotFound/permalink fallback,
post-localization model inference, published slug, numeric casting, and static
page IDs. Static pages and `/login` already conceal on HEAD, so they have GREEN
coverage, not RED claims. The first four shapes each have their own RED example
under both rule kinds.

The final mention regressions pin retained `data-orig-href` on both mention
classes. A preliminary `data-orig-src` variant was stripped by the real renderer;
no bypass is claimed for that stripped variant. Browser path resolution is
checked by explicit decoding/normalization, not a claimed native-browser pass.
No finite spec set certifies every possible URL spelling; the adopted contract
removes controller semantics from the boundary instead of claiming exhaustive
route coverage.

Only the authorized unit-2 inventory/README, unit-3 oracle/docs, new unit-4 spec
and this record changed. No commits, stashes, checkouts, resets, amendments,
pushes, migrations, core-database work, or service start/stop actions were used.
