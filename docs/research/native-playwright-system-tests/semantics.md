# Native pilot semantics and ownership

All three pinned pilot files are converted, retaining 35 examples and their fixtures/assertions. The implementation diff supplies the per-call mapping; this document records effective rules and exceptions. Measurements and profiling are documented in README.md.

| Control operation | Native operation | Preserved meaning / difference |
| --- | --- | --- |
| visit(path), back | Page.goto(path), Page.go_back | Same routes/history and ordinary Chromium; no global Ember/clientSettled post-navigation wait. Named visible locators/retrying assertions gate interactions. |
| find(selector).click | Locator.click | Scoped selector/visibility retained; strict cardinality rejects ambiguity. Locator resolution plus action share one timeout instead of outer finder then action waits. |
| fill_in | Locator.fill | Same input value and intended form behavior. |
| send_keys, keyboard typing | Locator.press / press_sequentially | Same individual key chords and keystroke input; typing is not replaced with fill. Original 100ms editor wait retained. Keyboard budget 30000ms. |
| DOM selection ranges | Locator.evaluate with original range algorithm | Same selection offsets/content; baseline already uses DOM selections. |
| have_css visible / no_css | be_visible on named visible locator / have_count(0) | Visible-only selectors retained; negative counts retry. |
| have_css text | contain_text regex with useInnerText:true, or anchored have_text regex with useInnerText:true for the exact badge | Case and horizontal spacing retained. Baseline visible_text collapses repeated newlines; native regex explicitly permits repeated newlines. String-normalized matcher is avoided for indentation-sensitive assertions. |
| exact field value | have_value | Exact Markdown value retained. |
| disabled CSS presence | be_visible + be_disabled | Visibility retained and disabled state explicitly asserted. |
| absence of disabled control | be_enabled | Also requires control attached/enabled, stronger than absence of a disabled selector. |
| hidden-inclusive selector count | have_count(1) or have_count(0) | Exact cardinality retained without forcing visibility. |
| checkbox checked | be_checked | Same checked state through native retrying matcher. |
| element count | have_count | Exact count of the corresponding visible elements. |
| internal visited tracking | original Ruby wait_for around Page.evaluate | Same 5s predicate. String wait_for_function is blocked by application CSP; no unsafe-eval bypass introduced. |
| authentication helper | native goto becoming endpoint + retrying response-body assertion | Cookie created inside actual native context and verified with authenticated UI. |

## Effective timeouts

Local 4s / CI 20s assertions, action budget default*1100ms (4.4s/22s), navigation and keyboard 30s. Native assertions/negative waits use Playwright Test expect_timeout; visibility locators specify :visible where Capybara default visibility formerly applied. Native helpers are scoped only to native_playwright:true; combining metadata keys in RSpec include leaked them into legacy system groups and was corrected.

## Responsibilities

- Shared RSpec/Rails hooks retain fixture transactions, server port/host, cache/Redis/MessageBus setup and cleanup, console/deprecation checks and error reporting.
- Minimal SystemServerDriver enables Capybara's existing Rack/Puma server and reset pending-request/error checks; it implements no browser finder/action API.
- NativeSystemBrowser owns SDK execution, Chromium launch, page/context lifecycle and per-example artifacts. Browser caches retain existing desktop/mobile/network-host family ownership.
- SystemDrivers owns common launch/device options for both paths. SystemBrowserReset owns the shared same-context/fresh-page policy, including all-storage clearing and permission reset.
- Native page objects return native locators and compose domain operations. Existing page objects remain for unmigrated examples. No generic adapter or Capybara-compatible DSL added.

## Scope and compatibility

- Two ordinary browser families in this pilot (desktop/mobile), matching the existing harness. Mixed jobs can retain both legacy and native browser families, adding coexistence overhead; full-job results must disclose this.
- Remote driver connections are explicitly unsupported in the prototype; normal CI is local Chromium.
- Global clientSettled/Ember-boot waits and Capybara-timeout MessageBus recovery are replaced by native actionability/assertions in migrated examples. This is a waiting strategy treatment as well as adapter removal. Reliability must be measured; do not call all savings pure Ruby overhead.
- Video transition behavior differs from an existing control bug: control ordinary-to-video after soft reset captures nothing, then fresh context records; native ensures recording on transition. Video/trace are disabled in the frozen timed pilot, so this cannot explain measured savings. Sticky control video callbacks can alter later reset policy; do not compare globally enabled video without resolving that experimental-control gap.
- StackProf wall mode targets the starting native thread and does not establish Rails request coverage. Complementary CPU profile captures controller execution. Both forms cover the entire pilot process, excluding browser/Node and separate DV development services; protocol observations complement waits.

## Failure cleanup verification

Cleanup runs in `ensure`, including when fatal deprecation assertions or browser evaluation fail during teardown. The [fault probe](recipes/isolation_fault_spec.rb) deliberately fails one control and one native example through a real console deprecation. The following examples verify a fresh page, database rollback, signed-out UI, and cleared local storage. Run it separately from performance measurements. Copy it under an ignored `spec/system` path so the harness loads system-test support:

```sh
mkdir -p tmp/native-playwright-research/spec/system
cp docs/research/native-playwright-system-tests/recipes/isolation_fault_spec.rb tmp/native-playwright-research/spec/system/isolation_fault_spec.rb
bin/rspec --seed 12345 --format documentation tmp/native-playwright-research/spec/system/isolation_fault_spec.rb
```

Expected result: four examples and exactly two failures, both named “emits a fatal deprecation after establishing browser state”. Both “starts the next example with a fresh page” checks must pass. The nonzero exit is intentional; this recipe is not part of normal CI discovery or the measured pilot. An earlier candidate produced a third failure because native state survived failed teardown; the repaired version preserves the original failure without leaking that state.

The pinned Ruby client's string `have_text` uses substring matching. The unread-count assertion therefore uses the JavaScript-compatible anchored regex `/^3$/` and `useInnerText:true`. Verification accepted `3`, retried a delayed change to `3`, and rejected `13`, `30`, and `3 new`.
