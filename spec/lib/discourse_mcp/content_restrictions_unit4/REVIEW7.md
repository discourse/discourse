**Review 7 — invalid UTF-8 host regression**

Baseline: `afe9215fe56bb761309732ca0bd1087155a335d3`; accepted finding from `ce7c7206ae3..afe9215fe56`. Added only the two requested regression spec files and this note for Part A. Production code is unchanged and these pins intentionally remain RED.

Final run, seed **57019**, hc terminal `t93` (`cr-u5-depth-final-red`): **all six Part A examples RED at the assertion level**. The combined run is 71 examples, 47 failures, 24 passing controls, no pending examples and no errors outside examples, in 12.54 seconds. The complete final receipt and source hashes are in [verification.json](../content_restrictions_unit5/verification.json). All runs used `LOAD_PLUGINS=1 RAILS_DB=discourse_test_mcp_content`, repository Ruby 4.0.7 and lockfile Bundler 4.0.23 through hc. `bin/lint --fix --verbose` passed after supplying Node 24.14.0 and pnpm 10.28.0 as well as Ruby in hc's PATH.

The settings pin uses exactly `https://%FF.example/page`. It first observes the URL in a usable unrestricted response, separately in current value and default, then activates a forum rule or PM-only rule. The required outcome is a usable HTTP 200 response with `value: null`, `default: null`, `redacted: true` in structuredContent and text JSON. HEAD instead returns **HTTP 500, JSON-RPC error -32603, "Internal error"** in each of the four cases. Thus a generic internal-error fallback cannot satisfy this test.

Authored text is reachable using `https://visitor@%FF.example/page`: a labelled link with userinfo. Each test first writes without a rule and verifies its exact raw and cooked href inside a rolled-back transaction. With a forum rule or PM-only rule, it must return the complete existing normal reference-refusal envelope (HTTP 200, `isError: true`, the standard content-policy message), preserving the full existing content-state snapshot. HEAD instead returns **HTTP 500 / -32603**. Both snapshot assertions pass, so the failure is the wrong error envelope rather than a persisted write.

The plain authored `https://%FF.example/page` cannot isolate this host-classifier defect: preliminary unrestricted cooking drops its href. The current sanitizer requires a word character, dot or hyphen after `//`; userinfo begins with a word character and preserves the malformed host. That calibration failure was replaced by the reachable userinfo form before the final run. This is a renderer limitation, not a new MCP plan fault.

No fixed IDs were added by Part A; setup reuses the existing token and write helpers with normal fabricated records. Unit 5's new fixed fixtures use a separate verified range.

**Exact inventory**

| File | Example name | Observed RED signature |
| --- | --- | --- |
| [review7_setting_urls_spec.rb](../content_restrictions_unit3/review7_setting_urls_spec.rb) | `DiscourseMcp::Server#call [cr-u3] conceals an invalid UTF-8 decoded host in setting default under forum_content without an error` | HTTP 500 / JSON-RPC -32603 "Internal error" instead of a usable settings response |
| [review7_setting_urls_spec.rb](../content_restrictions_unit3/review7_setting_urls_spec.rb) | `DiscourseMcp::Server#call [cr-u3] conceals an invalid UTF-8 decoded host in setting default under private_messages without an error` | HTTP 500 / JSON-RPC -32603 "Internal error" instead of a usable settings response |
| [review7_setting_urls_spec.rb](../content_restrictions_unit3/review7_setting_urls_spec.rb) | `DiscourseMcp::Server#call [cr-u3] conceals an invalid UTF-8 decoded host in setting value under forum_content without an error` | HTTP 500 / JSON-RPC -32603 "Internal error" instead of a usable settings response |
| [review7_setting_urls_spec.rb](../content_restrictions_unit3/review7_setting_urls_spec.rb) | `DiscourseMcp::Server#call [cr-u3] conceals an invalid UTF-8 decoded host in setting value under private_messages without an error` | HTTP 500 / JSON-RPC -32603 "Internal error" instead of a usable settings response |
| [review7_spec.rb](review7_spec.rb) | `DiscourseMcp::Server#call [cr-u4] refuses a labelled invalid UTF-8 decoded host under forum with the normal reference refusal` | INVALID UTF-8 HOST: expected the normal reference refusal, not an internal error; HTTP 500 / -32603 instead of the HTTP 200 reference refusal |
| [review7_spec.rb](review7_spec.rb) | `DiscourseMcp::Server#call [cr-u4] refuses a labelled invalid UTF-8 decoded host under pm with the normal reference refusal` | INVALID UTF-8 HOST: expected the normal reference refusal, not an internal error; HTTP 500 / -32603 instead of the HTTP 200 reference refusal |

**Calibration and receipts**

- `t8x` / `cr-u5-baseline`: preliminary run, 66 examples / 47 failures. Two authored cases exposed stripped hrefs; six cleanup fixtures in the other unit reloaded already-deleted `fab!` records. These are not counted as final guard RED evidence.
- `t8y` / `cr-u5-calibrated`: 67 examples / 45 failures, all assertion-level after correcting those calibrations.
- `t91` / `cr-u5-final-red`: linted candidate plus two additional passing controller controls; 69 / 45, all failures assertion-level.
- `t93` / `cr-u5-depth-final-red`: final linted oracle including two additional denied-subtree depth cases; 71 / 47, all failures assertion-level. The changed category file passed follow-up lint in `t92`.
- `t8z` lint failed before linters because hc lacked Node on PATH. Corrected `t90` lint passed; RuboCop corrected one fabricator shorthand and Syntax Tree completed.

No commit, stash, checkout, reset, amend, push, migration, core database access or service management was performed. The initial sandboxed hc launch could not open the existing core lock; the identical authorized RSpec command ran with sandbox escalation. No approval was rejected.
