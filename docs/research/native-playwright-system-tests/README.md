# Native Playwright system-test pilot

## Result

On pinned upstream `0c86723eb20b411a48651bfac3f4faee2e1a8147`, four clean paired runs of a 35-example pilot favored native Playwright. The median paired reduction was **1.83%**, ranging from **1.50% to 4.44%**. This is a small observed pilot difference, without a confidence claim about the full suite. The measured candidate snapshot is SHA256 `1d296c4070ab59ad1fd5ea81a99dfe2a351706a848759b4beb75f6ced87414c8`.

| Pair | Order | Control command seconds | Native command seconds | Reduction |
| --- | --- | ---: | ---: | ---: |
| 1 | Control, native | 77.111369 | 75.950180 | 1.505860% |
| 2 | Native, control | 77.261552 | 76.101410 | 1.501576% |
| 3 | Control, native | 78.485762 | 76.788406 | 2.162629% |
| 4 | Native, control | 78.320343 | 74.842894 | 4.440032% |

All eight official runs passed 35 examples with no failures, retries, or declared flaky-delay signals. No official pair was discarded. This sample cannot establish that the native harness is less flaky. Two setup attempts failed before examples (missing GNU time and an inventory import assumption), were retained, and were excluded from official timings. Both arms then completed warmups before the fixed four-pair sequence.

The predeclared compute-spending gate required four favorable pairs with median reduction at least 5% for full-job expansion. Extra pairs were permitted only for conflicting signs or a median within two percentage points of that gate. Neither expansion condition applied. Full-job and actual-CI performance comparisons were skipped. Normal PR CI is still required for correctness. These results do not establish a Tests-workflow wall-time gain or an eight-minute workflow.

## Treatment and scope

The pilot converts every example in `spec/system/code_login_spec.rb` (6), `spec/system/topic_list/glimmer_spec.rb` (10), and `spec/system/composer/prosemirror_code_spec.rb` (19). It retains all examples and assertions, including mobile behavior and editor keystrokes. Native locators/actions and retrying Playwright matchers replace the browser-facing Capybara DSL. A minimal Capybara null driver retains Rails server integration, transactional request visibility and server-error/pending-request handling. Domain page objects compose native operations.

Native waiting replaces adapter synchronization, including global settled/boot waits. The treatment therefore combines a different waiting implementation with fewer adapter/protocol operations; it does not isolate Ruby dispatch overhead. Page/context/reset policies match the control. No page reuse, asset minification, worker changes, request interception, or test consolidation was included.

A separate failure-artifact check identified an existing control video transition gap: after ordinary soft-reset examples, a later video example reused a non-recording page. The native implementation creates a recording context on that transition. Video/trace/theme-marker capture was disabled in both timed arms, so that difference is outside the timing treatment and must be disclosed as a compatibility change.

## Controlled method

The existing Tests workflow core/system job was executed sequentially through act 0.2.89 on a dedicated 16-logical-core, 31-GiB Linux host. Both arms used image digest `sha256:cc8daf6070c995b6378e091e92efe08fcc007ad2a8da6ff61c6b7305f7ca0b0e`, Ruby 3.4.11, Node 22.23.3, pnpm 10.34.5, Capybara 3.40.0, capybara-playwright-driver 0.5.10, playwright-ruby-client 1.62.0, Node Playwright 1.62.1, and ordinary Chromium 151.0.7922.34 revision 1234.

Temporary workflow copies flattened two parallel wrappers unsupported by act, skipped artifact uploads rejected by its artifact server, pinned checkout, and substituted the same focused pilot command in the existing system-test step. This is an adapted focused experiment, not a full-job benchmark. Normal prerequisite dependency/asset/database setup ran before each pilot invocation. Job containers were fresh; cached image/action/dependency policy was equivalent. One worker, seed 12345, browser flags/device settings, allocator/test logging and artifact policy were fixed. The control and candidate commands were:

```sh
bin/rspec --seed 12345 --format documentation spec/system/code_login_spec.rb spec/system/topic_list/glimmer_spec.rb spec/system/composer/prosemirror_code_spec.rb
```

The primary endpoint is monotonic elapsed time around spawning and waiting for the complete RSpec command, including Ruby startup, setup and teardown. Observer startup/output writes are outside that interval. Peak memory was not measured. Child CPU was observed separately; profiled protocol timings are supplementary and can overlap.

## Profiling

Matching entire-pilot StackProf wall and CPU runs use 1000-microsecond intervals and raw stacks, separately from official timing. The one measured worker starts profiling before loading RSpec and stops after suite teardown. Browser and Node execution are outside StackProf scope. Wall mode samples its starting native thread and has high reported missed counts; CPU mode is needed to establish actual Rails request-action coverage. Sampled stack widths are not elapsed wall-time percentages.

A synchronous protocol observer stores only class/method names, counts and durations, omitting asynchronous submission and all parameters/URLs. In the matching wall-profile runs, synchronous calls fell from **4,568 to 1,603**, while both arms retained **64 goto calls, 37 page creations and two browser launches**. Control navigations took 30.896 seconds in aggregate protocol observation, native navigations 31.174 seconds. Native matcher `expect` calls numbered 151 and accounted for 16.222 observed seconds. Those profiled timings are not official runtime comparisons or independent additive wall-time buckets.

### Whole-pilot sample evidence

| Arm | Mode | Captured samples | Reported missed samples | GC samples | Raw stack weight rendered |
| --- | --- | ---: | ---: | ---: | ---: |
| Control | Wall | 14,792 | 61,819 | 2,195 | 14,729 |
| Native | Wall | 12,471 | 60,810 | 2,226 | 12436 |
| Control | CPU | 4,897 | 1,013 | 524 | 4,893 |
| Native | CPU | 4,635 | 999 | 499 | 4,632 |

StackProf's raw stack-series weights do not exactly equal its headline captured-sample counts. The renderer uses the original raw series, without rescaling to force agreement. All four profiles cover the same complete command and one worker. Frames narrower than 0.1% of represented samples are hidden visually; retained folded stacks preserve their weights. Profiles are separate observations, not repeated performance endpoints.

Matching CPU profiles include Rails request-thread execution: `ApplicationController#with_resolved_locale` had 1,538 inclusive samples in control and 1,529 in native; `UsersController#update` 311 and 299; `SessionController#verify_login_code` 101 and 105; `TopicsController#show` 68 and 70. These are overlapping inclusive counts and must not be summed. Request work remained similar in these observations.

The Ruby synchronous protocol client frame `Playwright::Channel#send_message_to_server_result` had 213 inclusive CPU samples in control and 62 in native. Its metadata-building frame had 77 and 28. This supports reduced client work alongside the call-count decrease. It does not quantify browser/Node CPU or assign the observed wall-time reduction to a single cause.

The flamegraphs show startup/loading, fixture/database setup, request rendering and client work still present. CPU mode demonstrates request coverage; wall mode cannot show all-thread elapsed attribution. No flamegraph proves that Ember boot is the dominant end-to-end cost.

### Artifacts and reproduction

- Wall flamegraphs: [control](profiles/control-wall.svg), [native](profiles/candidate-wall.svg).
- CPU flamegraphs: [control](profiles/control-cpu.svg), [native](profiles/candidate-cpu.svg).
- [Per-worker provenance](profiles/provenance.json), [raw paired timings](pairs.csv), [method-only protocol observations](protocol.json), and [semantic mapping](semantics.md).
- [Frozen measured candidate patch](recipes/candidate-v1.patch.gz). Decompress this patch with `gzip -dc`, then apply it to the pinned baseline to reproduce the measured source snapshot, independently of later formatting or review changes. Verify the decompressed patch SHA256 against the value above.
- [Whole-suite profile observer](recipes/profile_suite.rb), [complete-command timer](recipes/time_command.rb).

Run the observer in separate processes for each arm and mode, with the same versions, environment, seed and pilot command:

```sh
NATIVE_PROFILE_MODE=wall bundle exec ruby -r ./docs/research/native-playwright-system-tests/recipes/profile_suite.rb bin/rspec --seed 12345 --format documentation spec/system/code_login_spec.rb spec/system/topic_list/glimmer_spec.rb spec/system/composer/prosemirror_code_spec.rb
NATIVE_PROFILE_MODE=cpu bundle exec ruby -r ./docs/research/native-playwright-system-tests/recipes/profile_suite.rb bin/rspec --seed 12345 --format documentation spec/system/code_login_spec.rb spec/system/topic_list/glimmer_spec.rb spec/system/composer/prosemirror_code_spec.rb
```

The default profile output is under `tmp/native-playwright-research/profile`. Raw profiles and diagnostic logs remain private because they can contain source paths and failure details. Published flamegraphs contain function names and weights only. Folded stacks are retained with the private raw artifacts and can be regenerated using the recipe. Render with StackProf 0.2.28 `--stackcollapse`, then FlameGraph commit `41fee1f99f9276008b7cd112fca19dc3ea84ac32` using `--width 1600 --minwidth 0.1% --countname samples`. Inspect artifacts before publication.

The measured source snapshot is v1. Required Ruby frozen-string directives and formatter wrapping were applied afterward. Those directives can change allocation behavior; the table and profiles above describe the archived v1 snapshot. Final-revision measurements and review are pending. No timing claim for the formatted revision is established yet.

## Recommendation

The evidence so far does not justify a broad conversion for runtime savings alone. Native Playwright substantially reduces synchronous call count, but the observed pilot gain is small and repeated navigation remains. Conversion also requires explicit ownership of lifecycle, authentication, fixture/server integration, artifacts and matcher semantics. A full-suite conversion could have different costs, particularly while native and legacy browser families coexist; no extrapolation is supported.
