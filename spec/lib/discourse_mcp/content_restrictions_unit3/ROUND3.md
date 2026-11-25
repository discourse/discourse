# Unit 3 round-3 regression oracle

Baseline: `6a77b9b3e85eb1f3d13406846f1a1cfa7047cde0`. This is an oracle-only
change; the paired implementer supplies the production fix afterward.

The new [round3_local_setting_urls_spec.rb](round3_local_setting_urls_spec.rb)
contains 16 examples. Each is observed RED for the stated retained URL. Each
restricted/allowed pair is calibrated without a rule, then exercised with exactly
the named rule. Absolute URLs use the actual Discourse base URL; every relative
path also has an absolute equivalent. Allowed controls use the same route shape
and remain visible. The existing unit 3 examples are retained.

## New example names and observed RED

For each restricted URL, three checks fail: the structured projection and parsed
JSON text projection keep the URL instead of `value: null`, `default: null`,
`redacted: true`; the complete Server response still contains the URL. Only those
checks fail. Calibration, successful usable results, route/target preconditions,
and allowed controls pass. Generated slugs below are from the recorded combined
run, seed `30931`; their sequence can vary with another seed or example selection.

| Exact example name | Observed RED signature |
| --- | --- |
| `[cr-u3] ListSiteSettings conceals absolute and relative raw URLs under forum_content` | 6 failed checks: `/raw/95510001`; `http://test.localhost/raw/95510001` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative posts/by_number URLs under forum_content` | 6 failed checks: `/posts/by_number/95510001/2`; `http://test.localhost/posts/by_number/95510001/2` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative nested_topics URLs under forum_content` | 6 failed checks: `/n/this-is-a-test-topic-19/95510001`; `http://test.localhost/n/this-is-a-test-topic-19/95510001` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative raw URLs under private_messages` | 6 failed checks: `/raw/95510001`; `http://test.localhost/raw/95510001` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative posts/by_number URLs under private_messages` | 6 failed checks: `/posts/by_number/95510001/2`; `http://test.localhost/posts/by_number/95510001/2` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative nested_topics URLs under private_messages` | 6 failed checks: `/n/this-is-a-private-message-31/95510001`; `http://test.localhost/n/this-is-a-private-message-31/95510001` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative category show URLs under forum_content` | 6 failed checks: `/c/94510001/show`; `http://test.localhost/c/94510001/show` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative category edit URLs under forum_content` | 6 failed checks: `/c/amazing-category-21/edit`; `http://test.localhost/c/amazing-category-21/edit` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative category find_by_slug URLs under forum_content` | 6 failed checks: `/c/amazing-category-19/find_by_slug`; `http://test.localhost/c/amazing-category-19/find_by_slug` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative renamed tag id redirect URLs under forum_content` | 6 failed checks: `/tags/cru3-r3-denied/97510001`; `http://test.localhost/tags/cru3-r3-denied/97510001` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative numeric tag name fallback URLs under forum_content` | 6 failed checks: `/tag/98510001.json`; `http://test.localhost/tag/98510001.json` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative redirect route URLs by their restricted destination under forum_content` | 6 failed checks: `/category/amazing-category-35/94510001`; `http://test.localhost/category/amazing-category-35/94510001` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative permalink URLs by their restricted target under forum_content` | 24 failed checks: `/cru3-r3-archive/0/0`; `http://test.localhost/cru3-r3-archive/0/0`; `/cru3-r3-archive/1/0`; `http://test.localhost/cru3-r3-archive/1/0`; `/cru3-r3-archive/2/0`; `http://test.localhost/cru3-r3-archive/2/0`; `/cru3-r3-archive/3/0`; `http://test.localhost/cru3-r3-archive/3/0` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative permalink URLs by their restricted target under private_messages` | 12 failed checks: `/cru3-r3-archive/0/0`; `http://test.localhost/cru3-r3-archive/0/0`; `/cru3-r3-archive/1/0`; `http://test.localhost/cru3-r3-archive/1/0` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative unrecognized local URLs under forum_content and keeps recognized allowed URLs` | 6 failed checks: `/cru3-r3-browser-only/opaque-reference`; `http://test.localhost/cru3-r3-browser-only/opaque-reference` retained in `tos_url.value`, in structured and JSON text output. |
| `[cr-u3] ListSiteSettings conceals absolute and relative unrecognized local URLs under private_messages and keeps recognized allowed URLs` | 6 failed checks: `/cru3-r3-browser-only/opaque-reference`; `http://test.localhost/cru3-r3-browser-only/opaque-reference` retained in `tos_url.value`, in structured and JSON text output. |

## Routing, target and weaker-implementation checks

The harness calls the real tool through DiscourseMcp::Server with a real admin and
OAuth token, schema-valid arguments and an enabled egress filter. No policy,
router, database lookup or serializer is stubbed.

Topic and post fixtures use separate new ID ranges. Post-number URLs identify a
real second post, and the topic ID is explicitly not an existing post ID. Raw
routes identify the topic, not the post. Nested replies are enabled in their
examples; their PM GET route redirects to the regular topic route. The category
examples assert the current categories controller parameters (`id` versus
`category_slug`).

The renamed-tag example first renames the real tag and removes its old slug/name.
It performs the real `/tags/<retired-slug>/<id>` redirect, then recognizes the JSON
route for the destination and checks the authoritative tag ID. This defeats
slug-only lookup. Numeric-name examples assert both that no tag has that numeric
ID and that the real tag is found by name, defeating numeric-ID-only lookup.

Redirects are a destination-governed class, represented by the Rails tag wildcard
redirect above and the categories controller's `/category/<slug>/<id>` redirect.
The latter example performs the real GET, checks the 302, and resolves its
Location to the real category. A redirect allowlist based only on the source
controller cannot satisfy both restricted and allowed controls.

Permalinks are a separate destination-governed class. Their opaque paths contain
no target ID, slug, name or resource-type hint. Real Permalink rows target topics,
posts, categories and tags under the forum rule, and PM topics/posts under the PM
rule. Preconditions check recognition as permalinks#show, exact target URL and
admin visibility. All target types have opaque allowed controls with the same
path prefix. Prefix blocking, checking only route IDs, and handling only topic
permalinks cannot satisfy the complete set.

Every shape keeps its allowed control after restrictions. Blanket hiding of
local URLs or refusing the whole tool therefore fails the oracle. These checks
against weaker behavior are fixture/contract discrimination; production code was
not edited to run alternative implementations.

## Unrecognized local URL decision

**Conceal unrecognized local URLs while any content rule is active.** Failure to
recognize a URL on the server is insufficient evidence that its destination is
outside governed content: browser routing or a subsequent redirect may resolve
it. This is a conservative disclosure rule, not a claim that the opaque fixture
currently resolves to a restricted record. The tests assert no server route and
no Permalink record for the opaque path, calibrate preservation without a rule,
and require concealment under forum-only and PM-only policy. A recognized allowed
topic URL remains visible in each example, so rejecting all local URLs fails.

This is distinct from a recognized URL whose target record is missing. The
round-2 missing-record decision remains unspecified for that case. External URLs
are outside this new local-URL contract.

## Verification and evidence refresh

Run with the repository Ruby (4.0.7 / Bundler 4), plugins loaded, and only the
isolated `discourse_test_mcp_content` database:

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit3/ \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb --seed 30931
```

Observed after lint: **40 examples, 16 failures, 0 pending and 0 outside-example
errors**, 43.66 seconds after loading. All 16 new examples are RED with 120 failed
assertions limited to retained restricted URLs. All 22 prior unit 3 examples and
both unit 2 enrichment examples pass. Targeted `bin/lint --fix` passes for the new
Ruby file; bin/lint has no core linter for these spec-directory Markdown/JSON
files, whose JSON and evidence are checked directly.

The machine-readable [round3_verification.json](round3_verification.json) records
per-example signatures and before/after evidence results. The refreshed inventory
keeps its graph and classifications, with per-operation/path notes for unit 4's
changed entry conditions. The [unit 2 refresh table](../content_restrictions_unit2/README.md#round-3-evidence-refresh-at-6a77b9b3e85)
records all 19 moved occurrences at 18 distinct locations, along with changes
whose existing evidence did not move. Historical verification files remain
historical.
