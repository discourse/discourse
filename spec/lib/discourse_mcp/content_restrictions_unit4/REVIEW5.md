**Review 5 — MCP content restrictions**

Baseline: `e775091f75f4d75fa7e53aa848402d97abfd303f`; reviewed fixes: `8a32e9ce84d..e775091f75f`. Only the two new spec files, this report, and the unit 2 inventory/README are changed. No implementation changes, commits, migrations, core database access or service management were performed. The regression examples deliberately remain RED against this HEAD.

Added 38 examples: **21 RED, 17 GREEN**. The refreshed inventory adds two passing existing examples: the combined run is **40 examples, 21 failures**, seed **85019**, 21.13 seconds. Every failure below was checked for its stated signature, including persisted state; none is a setup, permission or schema failure.

Fixed fixture range: `112_850_000..112_850_999`. A numeric scan of every existing `*_spec.rb` in units 1–4 (unit 1 is `content_restrictions/`) found no use before the new files were created. The actual fixtures use topic `112_850_001`, reviewable `112_850_020`, category `112_850_100` and topic `112_850_101`.

**Observed signatures**

- **LINK RED:** `WRITE REFUSAL: expected isError=true` received HTTP 200 with `isError: false` and created post/topic identifiers. `BROWSER HOST: labelled <shape> link was accepted` and `BROWSER HOST ATOMICITY: labelled <shape> link persisted content` also failed. Each unrestricted calibration first persisted the same raw and verified its labelled anchor; percent-encoded destinations survive cooking exactly.
- **SETTING RED:** `BROWSER HOST SETTING RETAINED in value` and `BROWSER HOST SETTING RETAINED in default`. In each example, all four assertions failed: current-value and default placements, each in structuredContent and the text JSON projection. The retained URL names the fixed restricted-topic fixture. The other field is an external ASCII URL, so checking only one field is insufficient. Both fields were first verified visible without a rule.
- **PM RED:** `WRITE REFUSAL: expected isError=true` received `isError: false` with `success: true`, `remove_reviewable_ids: [112850020]`, `version: 1` and `reviewable_id: 112850020`. `SYSTEM PM: revise_and_reject_post was accepted`, `SYSTEM PM ATOMICITY: revise_and_reject_post persisted a private message` and the content-state assertion also failed. The queued reply was rejected and a PM persisted despite the `private_messages` rule. No `additional_fields` were supplied.

**New example names and individual results**

Every name below is exact. In unit 4, `forum` means the forum rule alone and `pm` means the private_messages rule alone.

File: [review5_spec.rb](review5_spec.rb).

| Example | Observed result/signature |
| --- | --- |
| `[cr-u4] refuses a labelled ideographic_full_stop internal host under forum without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled ideographic_full_stop internal host under pm without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled fullwidth_full_stop internal host under forum without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled fullwidth_full_stop internal host under pm without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled halfwidth_ideographic_full_stop internal host under forum without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled halfwidth_ideographic_full_stop internal host under pm without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled percent_encoded_ideographic_full_stop internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_ideographic_full_stop internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_fullwidth_full_stop internal host under forum without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled percent_encoded_fullwidth_full_stop internal host under pm without persisting content` | GREEN: uniform reference refusal; complete content-state snapshot unchanged |
| `[cr-u4] refuses a labelled percent_encoded_halfwidth_ideographic_full_stop internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_halfwidth_ideographic_full_stop internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_zero_width_space internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_zero_width_space internal host under pm without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_soft_hyphen internal host under forum without persisting content` | LINK RED |
| `[cr-u4] refuses a labelled percent_encoded_soft_hyphen internal host under pm without persisting content` | LINK RED |
| `[cr-u4] accepts a labelled external ASCII host under forum` | GREEN: post persisted with external labelled anchor |
| `[cr-u4] accepts a labelled external ASCII host under pm` | GREEN: post persisted with external labelled anchor |
| `[cr-u4] refuses revise_and_reject_post under private_messages without persisting a system PM` | PM RED |
| `[cr-u4] permits revise_and_reject_post on an allowed target under the forum rule alone` | GREEN: rejected reviewable, exactly one system PM to queued author; original target posts unchanged |

File: [review5_setting_urls_spec.rb](../content_restrictions_unit3/review5_setting_urls_spec.rb).

| Example | Observed result/signature |
| --- | --- |
| `[cr-u3] conceals ideographic_full_stop host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals ideographic_full_stop host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals fullwidth_full_stop host setting values and defaults under forum_content` | GREEN: current/default placements redacted in both projections |
| `[cr-u3] conceals fullwidth_full_stop host setting values and defaults under private_messages` | GREEN: current/default placements redacted in both projections |
| `[cr-u3] conceals halfwidth_ideographic_full_stop host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals halfwidth_ideographic_full_stop host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals percent_encoded_ideographic_full_stop host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals percent_encoded_ideographic_full_stop host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals percent_encoded_fullwidth_full_stop host setting values and defaults under forum_content` | GREEN: current/default placements redacted in both projections |
| `[cr-u3] conceals percent_encoded_fullwidth_full_stop host setting values and defaults under private_messages` | GREEN: current/default placements redacted in both projections |
| `[cr-u3] conceals percent_encoded_halfwidth_ideographic_full_stop host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals percent_encoded_halfwidth_ideographic_full_stop host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals percent_encoded_zero_width_space host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals percent_encoded_zero_width_space host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] conceals percent_encoded_soft_hyphen host setting values and defaults under forum_content` | SETTING RED |
| `[cr-u3] conceals percent_encoded_soft_hyphen host setting values and defaults under private_messages` | SETTING RED |
| `[cr-u3] keeps external ASCII host setting values and defaults under forum_content` | GREEN: external current/default values visible in both projections |
| `[cr-u3] keeps external ASCII host setting values and defaults under private_messages` | GREEN: external current/default values visible in both projections |

**Controls, limits and weaker implementations**

The external ASCII link and setting controls pass under each rule independently. The forum-only revise/reject control passes through MCP on the same kind of allowed regular-topic target: status becomes `rejected`, exactly one PM has subtype `system_message`, the queued author is a recipient, its first post contains the original queued raw, and no queued reply is published to the target topic. Blanket refusal of active-rule calls or blanket refusal of revise/reject would fail these controls. Checking only current settings, only defaults, only one rule kind, or only literal Unicode separator spellings would leave a failing example.

**Could not pin as RED:** U+FF0E (fullwidth full stop) is already normalized by the installed backend, including its percent-encoded form. Literal U+3002/U+FF61 authored links also already receive the correct refusal. Those cases remain GREEN coverage. Their percent-encoded authored forms reproduce the bypass, and literal plus encoded U+3002/U+FF61 settings reproduce disclosure. No artificial failure or production mutation was introduced to make an already-correct case RED.

The installed Addressable IDNA method resolves to `addressable-2.9.2/lib/addressable/idna/pure.rb`. Reading that implementation and running it under the repository Ruby/Bundler showed: U+FF0E maps to ASCII dot via NFKC; U+3002 and U+FF61 produce `xn--review-five-siteexample-ek2v`; decoded U+200B and U+00AD produce `xn--review-five-site-sc6i.example` and `xn--review-five-site-iwa.example`. A local WHATWG `URL` probe resolves all five supplied browser-equivalent spellings to `review-five-site.example`. Installed markdown-it normalization calls punycode.toASCII, whose separator set includes all three Unicode dots; that explains the GREEN literal authored separator cases. These are local installed-source/runtime checks, not assumptions about an IDNA backend.

The moderation source confirms the control: `perform_revise_and_reject_post` invokes `SystemMessage.create` and returns a success/rejected result without assigning `created_post`. `Reviewable::PerformResult` only sets `created_post_topic` through its created_post setter; MCP’s stored-topic transaction checks that returned field. SystemMessage creates a PM with subtype system_message. The regression asserts the public MCP envelope and persisted records, with no expectations on future implementation helpers.

**Declined findings**

2. I accept the decline under the recorded scope decision: forum-audience MessageBus publications are not agent output; configured responders/automation egress are out of scope; the Redis duplicate key is an availability effect. No regression pin was added, and the inventory retains conditional native graph edges rather than claiming that transactions retract all egress.

4. I accept the decline: invariant 2 permits configured server-side rules to leave agent-created content restricted provided the agent receives no locator. The existing Server filter judges results after tool execution and refuses restricted topic/post identifiers. No automation-retag regression was added; this report does not broaden the user’s chosen scope.

**Inventory refresh**

Baseline inventory run: **2 examples, 1 failure**, with ten stale exact-line assertions at ten distinct locations; this HEAD did not reproduce an IndexError. The current source declarations/calls and the round-4 diff were read before updating. All 245 live exact evidence occurrences and graph references were checked twice directly after refresh. Counts remain 56 operation rows, 55 distinct write primitives, 116 native paths and three exclusions. Both existing inventory examples passed in the combined run; no IndexError remains in that run.

| Source | Evidence moves |
| --- | --- |
| `tools/moderation.rb` | `reviewable.perform` 754 → 759 |
| `tools/private_messages.rb` | ReplyPrivateMessage 310 → 315; InviteToPrivateMessage 349 → 354 |
| `tools/site_settings.rb` | UpdateSiteSetting 277 → 289; update! call 340 → 352 |
| `tools/topic_writes.rb` | submission category 145 → 152; ReplyTopic 172 → 180; EditPost 230 → 238; UpdateTopic 282 → 290; SetPostDeleted 436 → 444 |

**Run receipts**

All RSpec runs used `LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content`, through hc with `/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin` first on PATH (lockfile Bundler 4.0.23). The initial hc launch without that PATH failed before loading specs: `You must use Bundler 4 or greater with this lockfile.`

| hc terminal | Files/result |
| --- | --- |
| `t8j` / `cr-review5-inventory-red` | Inventory before edits: 2 examples, 1 failure, ten stale evidence assertions, seed 85019 |
| `t8k` / `cr-review5-red` | Initial two new specs: 26 examples, 13 failures, seed 85019; revealed GREEN literal separator cases |
| `t8m` / `cr-review5-combined` | Expanded new specs plus inventory: 40 examples, 21 failures, seed 85019; all 21 failures have the signatures above, all controls and both inventory examples pass |

Re-run the combined examples with:

```sh
PATH=/Users/saquetim/.local/share/mise/installs/ruby/4.0.7/bin:$PATH \
LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content bin/rspec \
  spec/lib/discourse_mcp/content_restrictions_unit4/review5_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit3/review5_setting_urls_spec.rb \
  spec/lib/discourse_mcp/content_restrictions_unit2/enrichment_spec.rb \
  --format documentation --seed 85019
```

The observed combined run used `--format json --out spec/lib/discourse_mcp/content_restrictions_unit4/REVIEW5.md`; that temporary receipt was read to produce this Markdown report.

Lint: `bin/lint --fix --verbose` on the two new Ruby files passed in hc terminal `t8q` (`cr-review5-lint-runtime`): RuboCop inspected two files with no offenses, and Syntax Tree completed. hc needed the installed pnpm 10.28.0 and Node 24.14.0 directories on PATH as well as Ruby; earlier launcher attempts failed before running linters. The repository wrapper reports no core linter for these Markdown/JSON paths. `git diff --check` passes; JSON parsing, all evidence and graph references were verified directly.
