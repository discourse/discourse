# Unit 3 round-2 regression oracle

This extends the five-finding oracle with the two accepted findings at HEAD
`c560ace5708`. The prior [verification.json](verification.json) remains historical;
[round2_verification.json](round2_verification.json) records this run.

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit3/ \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb --seed 20914
```

Observed: **24 examples, 8 failures**, no pending examples or outside-example errors,
21.31 seconds after loading. All eight new examples are RED; the fourteen prior
unit 3 examples and both unit 2 enrichment examples are GREEN. Targeted
`bin/lint --fix` passed for both new Ruby files.

## New examples and observed RED

Names are exact. Each row is one example. Detailed assertion signatures and RSpec
IDs are recorded in `round2_verification.json`.

| File | Example | Observed RED |
| --- | --- | --- |
| `local_setting_urls_spec.rb` | `[cr-u3] ListSiteSettings conceals absolute and relative category routes under forum_content` | Both /c/<slug>/91310001 and /c/91310001 remain, absolute and relative, including the category id and slug where present (10 failing assertions). Allowed category URLs pass. |
| `local_setting_urls_spec.rb` | `[cr-u3] ListSiteSettings conceals absolute and relative tag routes under forum_content` | Both /tag/cru3-route-denied and /tags/cru3-route-denied remain, absolute and relative (8 failing assertions). Allowed tag URLs pass. |
| `local_setting_urls_spec.rb` | `[cr-u3] ListSiteSettings conceals absolute and relative topic and post routes under forum_content` | The relative /p/93310002 URL and its absolute equivalent remain, including restricted post id 93310002 (4 failing assertions). All three /t/... route forms are already concealed. Allowed URLs through all four route forms pass. |
| `local_setting_urls_spec.rb` | `[cr-u3] ListSiteSettings conceals absolute and relative topic and post routes under private_messages` | The relative /p/93310002 URL and its absolute equivalent remain, including restricted post id 93310002 (4 failing assertions). All three /t/... route forms are already concealed. Allowed URLs through all four route forms pass. |
| `typed_content_settings_spec.rb` | `[cr-u3] GetTheme conceals top-level and nested post values and defaults under forum_content` | Restricted id 93310001 remains in top_level_restricted_value, top_level_restricted_default, nested_restricted_value and nested_restricted_default, in structured and JSON text payloads (8 failing assertions). Both allowed controls pass. |
| `typed_content_settings_spec.rb` | `[cr-u3] GetTheme conceals top-level and nested post values and defaults under private_messages` | Restricted id 93310001 remains in top_level_restricted_value, top_level_restricted_default, nested_restricted_value and nested_restricted_default, in structured and JSON text payloads (8 failing assertions). Both allowed controls pass. |
| `typed_content_settings_spec.rb` | `[cr-u3] GetTheme conceals top-level and nested topic values and defaults under forum_content` | Restricted id 92310001 remains in top_level_restricted_value, top_level_restricted_default, nested_restricted_value and nested_restricted_default, in structured and JSON text payloads (8 failing assertions). Both allowed controls pass. |
| `typed_content_settings_spec.rb` | `[cr-u3] GetTheme conceals top-level and nested topic values and defaults under private_messages` | Restricted id 92310001 remains in top_level_restricted_value, top_level_restricted_default, nested_restricted_value and nested_restricted_default, in structured and JSON text payloads (8 failing assertions). Both allowed controls pass. |

## Fixture scope and controls

Both files use the existing real administrator/OAuth harness and call tools through
`DiscourseMcp::Server`, with real records, schema-validated arguments and fresh
request contexts. No policy, routing, serializer or renderer is stubbed; the Server
egress filter remains enabled.

The typed-reference examples use neutral property name `reference`, governed by a
`topic` or `post` schema, rather than relying on names such as `topic_id`. Each
example has **four independent settings**: top-level value, top-level default,
nested value and nested default. Every restricted default has an allowed current
value; every restricted current value has an allowed default. This prevents a
value-only/default-only or top-level-only correction from hiding a missed case.
Separate top-level and nested allowed controls must remain intact. PM examples
have only the private_messages rule; forum examples deny the real topic category.
Post IDs and topic IDs differ, so treating a post ID as its topic ID cannot pass.
Only typed setting values/defaults are scanned, in both structured and JSON text
payloads. Raw settings YAML, code fields and schema source are not asserted.

URL examples calibrate both restricted and allowed `tos_url` values before the
rule, then compare output after applying exactly the relevant rule. Each route is
covered in relative and absolute form, and allowed content through the **same**
route must stay intact. The topic/post examples include `/p/<post_id>`,
`/t/<slug>/<topic_id>/<post_number>`, `/t/<topic_id>/<post_number>` and `/t/<topic_id>`.
The category example covers `/c/<slug>/<category_id>` and `/c/<category_id>`; the
tag example covers `/tag/<name>` and `/tags/<name>`. A real second post exercises
post-number routes. Forum rules deny both the fixture category and tag; PM-only
rules restrict PM topics and their posts. Complete responses are checked for
restricted locators, including their structured and JSON text representations.

The `/t/...` forms already conceal correctly on this HEAD; they remain passing
controls in each topic/post example. Those examples are RED specifically for
`/p/<post_id>`. Category and tag examples are RED for every requested route form.
All allowed URL controls pass, so blocking ListSiteSettings or hiding all local
URLs cannot satisfy this oracle.

## Missing-record decision

Concealment of missing-record URLs is not required. These are stored administrator-authored values, and agents cannot mutate site settings while any content rule is active, so this interface does not allow agents to submit arbitrary URL candidates as an existence probe. A missing record has no governed content. This oracle leaves preservation versus redaction of missing URLs unspecified; any future agent-writable URL/read surface needs its own existence-oracle review.

## Exact-line evidence

Before the refresh, the existing enrichment exact-line example failed with all
15 stale references (first `groups.rb:400`). After re-review and refresh, both
enrichment examples pass. All 245 exact evidence occurrences and graph references
were also rechecked directly. The inventory retains all 56 operation rows,
55 write primitives, 116 paths and three exclusions. The complete prior/current
move table and behavior notes are in the
[unit 2 README](../content_restrictions_unit2/README.md#round-2-evidence-refresh-at-c560ace5708),
with per-row notes and all 15 moves in the inventory's `round2_review` metadata.
