# Unit 3 content-restriction regression oracle

Test-only oracle for the five accepted findings in `fc63dd894d5..3af1cfab93a`.
Every example contains `[cr-u3]`. Tools run through `DiscourseMcp::Server` with a real
administrator, issued OAuth token, current registry scopes, schema-validated arguments and
real records. Each request gets a fresh request context. No policy/serializer/renderer is
stubbed, and the Server egress check stays active.

```sh
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit3/ \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb --seed 32701
```

The final run against HEAD `3af1cfab93a` completed in 8.99 seconds (after loading):
**14 unit 3 examples RED, both unit 2 enrichment examples GREEN**, no pending examples,
no outside-example errors. Targeted `bin/lint --fix` passed for all five Ruby files.
`bin/lint` has no core linter for this JSON inventory or Markdown; all 245 exact evidence
occurrences and graph references were additionally checked directly.

The hc environment needed the installed Ruby 4.0.7 path; lint additionally needed the
installed Node/pnpm paths. The initial run stopped at Bundler before loading examples.
Earlier development runs exposed fixture errors (notification-default uniqueness,
search indexing disabled by the test environment, group message-state setup and YAML
aliases); those are corrected. Only the final run recorded in
[verification.json](verification.json) is the regression evidence.

## Test inventory and observed RED

Each row below is one example; names are exact. `server_support.rb` supplies the dispatcher
and output assertions and defines no examples. Failure signatures, RSpec IDs, seed and
run summary are also recorded in `verification.json`.

| File | Example | Observed RED |
| --- | --- | --- |
| `category_selectors_spec.rb` | `[cr-u3] discourse_filter_topics treats restricted category selectors like missing categories under denied_tag` | Positive/exact selectors return the allowed topic in the restricted category versus no topic for a missing category; negative/negative-exact exclude it versus retaining it for a missing category. All four comparisons fail. |
| `category_selectors_spec.rb` | `[cr-u3] discourse_filter_topics treats restricted category selectors like missing categories under selected_allowlist_by_tag` | Positive/exact selectors return the allowed topic in the restricted category versus no topic for a missing category; negative/negative-exact exclude it versus retaining it for a missing category. All four comparisons fail. |
| `category_selectors_spec.rb` | `[cr-u3] discourse_search treats restricted category selectors like missing categories under denied_tag` | Positive/exact/category-hashtag/exact-hashtag selectors return the allowed topic in the restricted category versus no topic for a missing category. All four comparisons fail; negative category selector equivalence passes. |
| `category_selectors_spec.rb` | `[cr-u3] discourse_search treats restricted category selectors like missing categories under selected_allowlist_by_tag` | Positive/exact/category-hashtag/exact-hashtag selectors return the allowed topic in the restricted category versus no topic for a missing category. All four comparisons fail; negative category selector equivalence passes. |
| `category_selectors_spec.rb` | `[cr-u3] discourse_search_posts treats restricted category selectors like missing categories under denied_tag` | Positive/exact/category-hashtag/exact-hashtag selectors return the allowed topic in the restricted category versus no topic for a missing category. All four comparisons fail; negative category selector equivalence passes. |
| `category_selectors_spec.rb` | `[cr-u3] discourse_search_posts treats restricted category selectors like missing categories under selected_allowlist_by_tag` | Positive/exact/category-hashtag/exact-hashtag selectors return the allowed topic in the restricted category versus no topic for a missing category. All four comparisons fail; negative category selector equivalence passes. |
| `groups_spec.rb` | `[cr-u3] discourse_get_group conceals restricted notification defaults and preserves allowed defaults` | Denied tag id 91300003, name cru3-denied-tag and slug cru3-denied-slug returned at all five notification levels. Restricted category id is absent and allowed defaults remain. |
| `groups_spec.rb` | `[cr-u3] discourse_get_group exposes identical message metadata for no messages and a denied-tag message` | Both structured and JSON text payloads change has_messages false -> true and message_count 0 -> 1 after only a denied-tag PM is added. |
| `groups_spec.rb` | `[cr-u3] discourse_update_group conceals restricted notification defaults and preserves allowed defaults` | Denied tag id 91300003, name cru3-denied-tag and slug cru3-denied-slug returned at all five notification levels. Restricted category id is absent and allowed defaults remain. |
| `groups_spec.rb` | `[cr-u3] discourse_update_group exposes identical message metadata for no messages and a denied-tag message` | Both structured and JSON text payloads change has_messages false -> true and message_count 0 -> 1 after only a denied-tag PM is added. |
| `site_settings_spec.rb` | `[cr-u3] ListSiteSettings conceals personal-message URLs with only private_messages active and preserves public URLs` | Returned tos_url contains /t/cru3-private-legal-destination/92300001, the message slug and id. The public-topic URL control passes. |
| `theme_settings_spec.rb` | `[cr-u3] GetTheme conceals restricted category_list values and defaults independently` | Restricted category id 91300011 remains in the value-only and default-only settings, in both structured and JSON text payloads. Allowed control passes. |
| `theme_settings_spec.rb` | `[cr-u3] GetTheme conceals restricted objects values and defaults independently` | Restricted category id 91300011 and tag name cru3-theme-denied remains in the value-only and default-only settings, in both structured and JSON text payloads. Allowed control passes. |
| `theme_settings_spec.rb` | `[cr-u3] GetTheme conceals restricted tag_list values and defaults independently` | Restricted tag name cru3-theme-denied remains in the value-only and default-only settings, in both structured and JSON text payloads. Allowed control passes. |

## Scope and strength of the fixtures

Group defaults cover watching, tracking, first-post watching, regular and muted levels,
with separately persisted groups because defaults are unique per group/category or tag.
Unrestricted calibration proves the actual serialized tag objects and category IDs are
present before installing the rule. Allowed defaults must survive. The RED comes from
the denied tag object; the restricted category check already passes on this HEAD.

The message test reads the **same group** before and after adding a real denied-tag PM
through `Topic#invite_group`. It compares presence and value of both metadata fields,
independently in structured and JSON text payloads. PM-off is not active; a fix that
only checks the private_messages rule leaves this example RED. Either omission or
policy-filtered counts can satisfy the observable contract.

Theme calibration persists independent `restricted_value` (allowed default),
`restricted_default` (allowed current value) and `allowed_control` settings for each
of the three types. This catches a value-only or default-only correction. Only typed
setting `value`/`default` output is scanned, in both structured and decoded JSON text
payloads. Raw settings YAML, code fields and schema source are deliberately outside
these assertions under the accepted copied-content boundary.

The URL fixture uses the same real `tos_url` setting first for the PM URL, then for a
public-topic URL while **only** private_messages is active. The public URL must remain
readable. Blocking the entire tool or redacting every URL cannot satisfy the control.

Selector fixtures leave the topic inside the restricted category **allowed**, with a
second allowed topic outside it. In denied_tag mode only the definition topic carries
the denied tag. In selected_allowlist_by_tag mode both ordinary topics carry the selected
tag and there are no selected categories. GetCategory independently confirms the category
answers as missing, while unfiltered discovery confirms both ordinary topics remain
visible. Thus filtering topics by category restriction would break the controls.

FilterTopics covers `category:`, `-category:`, `=category:` and `-=category:`.
Search/SearchPosts cover `category:`, `-category:`, `category:=`, `#` and `#=`.
On this HEAD negative search category syntax is not an advanced category filter (the
current search registrations recognize positive category syntax); its equivalence check
already passes. The other four search selectors are independently RED in both rule modes.
Every comparison includes HTTP status, headers and the complete result. Only an exact
caller query echo at `meta.term` and its JSON text copy is substituted; text formatting
and all other fields remain unchanged.

The inventory refresh and its complete old/current evidence-line table live in the
[unit 2 README](../content_restrictions_unit2/README.md#unit-3-evidence-refresh-at-3af1cfab93a).

## Round 2 at `c560ace5708`

See [ROUND2.md](ROUND2.md) for the eight new typed topic/post and local-route URL examples, their observed RED signatures, the missing-record decision and the current full-run results. The earlier run recorded above remains historical.
