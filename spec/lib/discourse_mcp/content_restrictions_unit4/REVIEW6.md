**Review 6 — MCP content restrictions**

Baseline: `763a20295f032a73d837f638bdea40d9bc42093f`; reviewed fixes: `78600db48de..763a20295f0`. Added the two requested spec files and this report; refreshed only the unit 2 inventory and README. Production code is unchanged. No commit, stash, checkout, reset, amend, push, migration, core database access or service management was performed. The accepted regressions intentionally remain RED against HEAD.

Final run, seed **86019**: **64 examples, 44 failures**, 31.43 seconds, no pending examples or errors outside examples. The new files contribute **62 examples: 44 RED, 18 GREEN**; the existing enrichment file contributes **2 GREEN**. Every RED below was checked against its complete exception message for the stated signature. No final failure is a calibration, schema, authorization or fixture failure.

Fixed fixture range: `112_860_000..112_860_999`. Before creating the specs, a numeric scan of all 47 Ruby/JSON files in units 1–4 found no literal in this range; unit 1 is `content_restrictions/`. Actual fixed fixtures are topic `112_860_001`, category `112_860_100` and topic `112_860_101`. The existing unit 2 generated fixture offsets were also read; they use separate ranges.

**Observed RED signatures**

| Code | Observed behavior |
| --- | --- |
| LINK RED | `WRITE REFUSAL: expected isError=true` receives HTTP 200 with `isError: false` and created post/topic identifiers. `BROWSER HOST: labelled <shape> link was accepted` and `BROWSER HOST ATOMICITY: labelled <shape> link persisted content` also fail: three assertions per example. The labelled destination first survives an unrestricted write with its exact expected cooked href. |
| SETTING RED | `BROWSER HOST SETTING RETAINED in value` and `BROWSER HOST SETTING RETAINED in default`: four assertions per example, covering the current-value and default placements separately, each in structuredContent and text JSON. Both fields were calibrated visible without a rule. Under the rule the internal URL remains visible instead of both fields becoming null with `redacted: true`. |
| IPV6 LINK RED | The unrestricted labelled anchor survives with its exact href. After activating the rule, `MCP SUCCESS tool error` receives HTTP 200 with `isError: true` and `This capability is turned off by the site's AI content restrictions`. The expected successful external-link write is refused. |
| IPV6 SETTING RED | `EXTERNAL HOST SETTING REDACTED in value` and `EXTERNAL HOST SETTING REDACTED in default`: both fields become null with `redacted: true`. Eight assertions fail per example: expected values plus the redacted flag, in both projections and each field placement. |
| IPV6 CLASSIFIER RED | `EXTERNAL IPV6 CLASSIFIED INTERNAL by URI::HTTPS` and `EXTERNAL IPV6 CLASSIFIED INTERNAL by Addressable::URI`: both return true where false is expected. These two examples isolate literals without userinfo from the separate renderer limitation described below. |

**Host fixtures and controls**

| Shape | URL host or authority | Configured site host |
| --- | --- | --- |
| `percent_encoded_capital_sharp_s` | `fa%E1%BA%9E.example` | `xn--fa-hia.example` |
| `unicode_capital_sharp_s` (settings) | `faẞ.example` | `xn--fa-hia.example` |
| `unicode_sharp_s` (authored control) | `faß.example` | `xn--fa-hia.example` |
| `ipv4_short_dotted` | `127.1` | `127.0.0.1` |
| `ipv4_decimal_integer` | `2130706433` | `127.0.0.1` |
| `ipv4_hex_integer` | `0x7f000001` | `127.0.0.1` |
| `ipv4_octal_dotted` | `0177.0.0.1` | `127.0.0.1` |
| `ipv4_leading_zero_dotted` | `127.000.000.001` | `127.0.0.1` |
| `ipv4_octal_integer` | `017700000001` | `127.0.0.1` |
| `canonical_punycode` (internal control) | `xn--fa-hia.example` | `xn--fa-hia.example` |
| `canonical_ipv4` (internal control) | `127.0.0.1` | `127.0.0.1` |
| `ipv6_literal` | `[2001:db8::6]` | `127.0.0.1` |
| `ipv6_with_port` | `[2001:db8::6]:8443` | `127.0.0.1` |
| `ipv6_with_userinfo` | `visitor:password@[2001:db8::6]` | `127.0.0.1` |
| `ipv6_with_userinfo_and_port` | `visitor:password@[2001:db8::6]:8443` | `127.0.0.1` |
| `ascii_host` (external control) | `external.example` | `127.0.0.1` |
| `canonical_ipv4` (external control) | `192.0.2.6` | `127.0.0.1` |

A local WHATWG `URL` probe maps `fa%E1%BA%9E.example` and `faẞ.example` to `xn--fa-hia.example`, and all six numeric spellings to `127.0.0.1`. The authored bypass fixture retains its percent-encoded destination through cooking. Tests assert existing public behavior and use no proposed implementation API. Only the two narrower IPv6 examples call the existing `InternalHosts.include?` directly, with the same two parser types the current consumers use.

Every link/setting scenario exercises forum-only and PM-only rules independently. Unrestricted write calibrations run inside rolled-back transactions. Refused internal links require the uniform reference-error envelope and the complete existing content-state snapshot to remain unchanged. Canonical internal punycode/IPv4 controls already give that refusal. External ASCII and canonical external IPv4 links already persist successfully, and their setting values/defaults remain visible. The lowercase Unicode authored control cooks to the site's canonical punycode host and is correctly refused.

Checked the fixtures against plausible weaker behavior: blanket rejection/redaction under active rules fails the external controls; rejecting every IP host fails the canonical external IPv4 controls; inspecting only current values or only defaults fails the opposite-field placement; fixing only one policy kind leaves the other independently failing. No production mutation was executed within this test-only scope.

**Exact new example names and individual results**

For unit 4 RPC examples, `forum` means the forum rule alone and `pm` means the private_messages rule alone. Classifier examples are policy-independent host checks. The codes above identify the verified exception signature for each RED example.

File: [review6_spec.rb](review6_spec.rb).

| Exact example name | Observed result/signature |
| --- | --- |
| `[cr-u4] refuses a labelled canonical_ipv4 internal host under forum without persisting content` | GREEN: uniform refusal; content state unchanged |
| `[cr-u4] refuses a labelled canonical_ipv4 internal host under pm without persisting content` | GREEN: uniform refusal; content state unchanged |
| `[cr-u4] refuses a labelled canonical_punycode internal host under forum without persisting content` | GREEN: uniform refusal; content state unchanged |
| `[cr-u4] refuses a labelled canonical_punycode internal host under pm without persisting content` | GREEN: uniform refusal; content state unchanged |
| `[cr-u4] refuses a labelled ipv4_decimal_integer internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_decimal_integer internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_hex_integer internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_hex_integer internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_leading_zero_dotted internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_leading_zero_dotted internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_octal_dotted internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_octal_dotted internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_octal_integer internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_octal_integer internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_short_dotted internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled ipv4_short_dotted internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_capital_sharp_s internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_capital_sharp_s internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled unicode_sharp_s internal host under forum without persisting content` | GREEN: uniform refusal; content state unchanged |
| `[cr-u4] refuses a labelled unicode_sharp_s internal host under pm without persisting content` | GREEN: uniform refusal; content state unchanged |
| `[cr-u4] accepts a labelled external ascii_host under forum` | GREEN: labelled external anchor persisted |
| `[cr-u4] accepts a labelled external ascii_host under pm` | GREEN: labelled external anchor persisted |
| `[cr-u4] accepts a labelled external canonical_ipv4 under forum` | GREEN: labelled external anchor persisted |
| `[cr-u4] accepts a labelled external canonical_ipv4 under pm` | GREEN: labelled external anchor persisted |
| `[cr-u4] accepts a labelled external ipv6_with_userinfo under forum` | IPV6 LINK RED |
| `[cr-u4] accepts a labelled external ipv6_with_userinfo under pm` | IPV6 LINK RED |
| `[cr-u4] accepts a labelled external ipv6_with_userinfo_and_port under forum` | IPV6 LINK RED |
| `[cr-u4] accepts a labelled external ipv6_with_userinfo_and_port under pm` | IPV6 LINK RED |
| `[cr-u4] classifies an external ipv6_literal as external with both URL parsers` | IPV6 CLASSIFIER RED |
| `[cr-u4] classifies an external ipv6_with_port as external with both URL parsers` | IPV6 CLASSIFIER RED |

File: [review6_setting_urls_spec.rb](../content_restrictions_unit3/review6_setting_urls_spec.rb).

| Exact example name | Observed result/signature |
| --- | --- |
| `[cr-u3] conceals canonical_ipv4 host setting values and defaults under forum_content` | GREEN: both field placements redacted in both projections |
| `[cr-u3] conceals canonical_ipv4 host setting values and defaults under private_messages` | GREEN: both field placements redacted in both projections |
| `[cr-u3] conceals canonical_punycode host setting values and defaults under forum_content` | GREEN: both field placements redacted in both projections |
| `[cr-u3] conceals canonical_punycode host setting values and defaults under private_messages` | GREEN: both field placements redacted in both projections |
| `[cr-u3] conceals ipv4_decimal_integer host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals ipv4_decimal_integer host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals ipv4_hex_integer host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals ipv4_hex_integer host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals ipv4_leading_zero_dotted host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals ipv4_leading_zero_dotted host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals ipv4_octal_dotted host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals ipv4_octal_dotted host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals ipv4_octal_integer host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals ipv4_octal_integer host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals ipv4_short_dotted host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals ipv4_short_dotted host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals percent_encoded_capital_sharp_s host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals percent_encoded_capital_sharp_s host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals unicode_capital_sharp_s host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals unicode_capital_sharp_s host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] keeps external ascii_host setting values and defaults under forum_content` | GREEN: both field placements visible in both projections |
| `[cr-u3] keeps external ascii_host setting values and defaults under private_messages` | GREEN: both field placements visible in both projections |
| `[cr-u3] keeps external canonical_ipv4 setting values and defaults under forum_content` | GREEN: both field placements visible in both projections |
| `[cr-u3] keeps external canonical_ipv4 setting values and defaults under private_messages` | GREEN: both field placements visible in both projections |
| `[cr-u3] keeps external ipv6_literal setting values and defaults under forum_content` | IPV6 SETTING RED |
| `[cr-u3] keeps external ipv6_literal setting values and defaults under private_messages` | IPV6 SETTING RED |
| `[cr-u3] keeps external ipv6_with_port setting values and defaults under forum_content` | IPV6 SETTING RED |
| `[cr-u3] keeps external ipv6_with_port setting values and defaults under private_messages` | IPV6 SETTING RED |
| `[cr-u3] keeps external ipv6_with_userinfo setting values and defaults under forum_content` | IPV6 SETTING RED |
| `[cr-u3] keeps external ipv6_with_userinfo setting values and defaults under private_messages` | IPV6 SETTING RED |
| `[cr-u3] keeps external ipv6_with_userinfo_and_port setting values and defaults under forum_content` | IPV6 SETTING RED |
| `[cr-u3] keeps external ipv6_with_userinfo_and_port setting values and defaults under private_messages` | IPV6 SETTING RED |

**Could not pin and calibration limits**

- A literal uppercase-sharp-S authored destination is not a valid reproduction of navigation back to the site after the current markdown renderer rewrites it: the preliminary write persisted `https://xn--fa-64s.example/...`, which the local WHATWG parser rejects as an invalid URL. That preliminary example was removed. The encoded uppercase-sharp-S labelled destination is the authored RED reproduction; literal uppercase and percent-encoded uppercase settings are both RED. The lowercase `faß.example` authored control is GREEN because its cooked destination is already `xn--fa-hia.example`.
- End-to-end labelled IPv6 URLs **without userinfo**, including the port-only form, cannot isolate this policy defect on HEAD: unrestricted cooking already removes their href. The renderer's absolute-URL allow regex requires a word character, dot or hyphen immediately after `//` (`frontend/discourse/pretty-text/sanitizer.ts:48`). Those preliminary calibration failures were removed. Two final classifier examples pin the incorrect internal classification for both parser types, and all four IPv6 setting shapes are RED. End-to-end labelled IPv6 with userinfo and with userinfo plus port both survive unrestricted cooking and then reproduce the policy refusal. This report does not claim the no-userinfo rendered-link symptom is solely an MCP defect.

**View on the declined finding**

I accept finding 2's decline and do not contest it. The plan's invariant 2 explicitly permits newly created content to end up restricted when the agent gets no locator back. Its section 8 scopes the reviewable refusal to actions sending agent-authored PMs; it separately names custom silence/suspend messages and membership-request flows. A fixed system notice to the poster does not grant the agent PM access.

Source checks support that reading: `ReviewableFlaggedPost.action_aliases` maps `disagree_and_restore` to `disagree`; `perform_disagree` invokes `notify_poster` only for a hidden, non-trashed post and returns its reviewable result. `notify_poster` queues `send_system_message` for `post.user_id` using the fixed `flags_disagreed` template with the stored post raw and URL, not agent-supplied message text. The result does not set a created post, and the serializer includes created-post/topic IDs only when those result fields are present. This is source evidence, not a new runtime notice test. No blanket refusal test was added. The existing `revise_and_reject_post` PM-off refusal remains a conservative extra (`lib/discourse_mcp/tools/moderation.rb:300`).

**Inventory refresh**

Before editing, seed 86019 observed **2 examples, 1 failure**, with exactly two stale assertions at `moderation.rb:714` and `moderation.rb:759`; no `IndexError` occurred. Re-read the current guard, declaration and dispatch body, plus `78600db48de..763a20295f0`, before updating:

| Evidence | Prior → current | Reason |
| --- | --- | --- |
| `PerformReviewableAction` declaration | 714 → 719 | Preceding PM-off revise/reject guard adds five lines |
| Native `reviewable.perform` dispatch | 759 → 764 | Same preceding guard; stored-topic transaction and permitted dispatch remain |

`unit4_review6_refresh` records the moves and current entry conditions. Earlier notes remain historical. All **245 live exact evidence occurrences** and graph references were checked twice directly after refresh. The inventory retains **56 operation rows, 55 distinct write primitives, 116 paths and three exclusions**. Both existing enrichment examples pass in the final combined run, with **no IndexError**. The README records this refresh.

**Run receipts**

All RSpec runs used `LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content` through hc, with the repository Ruby 4.0.7 directory first on PATH and lockfile Bundler 4.0.23. The initial sandboxed hc launch could not open its existing core lock; the identical authorized command ran with sandbox escalation. No service was started or stopped.

| hc terminal / name | Result |
| --- | --- |
| `t8r` / `cr-review6-inventory-red` | Before refresh: 2 examples, 1 failure; exactly the two stale moderation assertions; no IndexError |
| `t8s` / `cr-review6-red` | Preliminary calibration: 64 examples, 48 failures. Exposed the no-userinfo renderer limitation and uppercase-Unicode cooked destination; those examples were revised as described above |
| `t8w` / `cr-review6-combined` | Final new specs plus enrichment: 64 examples, 44 intentional regression failures, 31.43 seconds, seed 86019; all signatures checked, 18 new GREEN controls and 2 GREEN enrichment examples |
| `t8t` / `cr-review6-lint` | Launcher failed before linters because the supplied pnpm directory incorrectly included `/bin`; the wrapper also reported no core linter for the Markdown/JSON paths |
| `t8v` / `cr-review6-lint-runtime` | Corrected installed pnpm path: `bin/lint --fix --verbose` passed; RuboCop inspected both new files with no offenses, Syntax Tree completed |

The RSpec JSON receipt temporarily occupied this permitted report path and was read to generate this Markdown report. Re-run the final set with:

```sh
PATH=/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin:$PATH \
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit4/review6_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/review6_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --format documentation --seed 86019
```

JSON parsing, the live evidence/graph references and `git diff --check` were verified directly. No GREEN claim is made for the implementation: these files are regression pins for the next paired-build fix.
