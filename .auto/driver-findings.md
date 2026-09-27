# System-test driver findings

Updated 2026-09-27. Measurements below compare the existing Playwright-backed
Capybara driver with the native direct-CDP driver on the pinned application
source revision `bf55a44c2872738f7ae2664d6fec3d6d8779190f`. Timings are elapsed
seconds for the system-test step unless marked otherwise. These are aggregate
CI measurements; raw logs and profiles remain local.

## What the current Rust CDP implementation contains

The Capybara driver and its Ruby-facing system-test behavior are already in
Ruby. The native implementation is not a full Capybara rewrite in Rust: a Rust
subprocess launches Chrome with `--remote-debugging-pipe`, forwards CDP
messages, and implements browser-side helpers such as element lookup and
input. Ruby sends those commands to the subprocess and receives the responses.
This distinction matters for the proposed Ruby experiment: keep the Ruby
Capybara adapter fixed and compare the Rust versus Ruby CDP transport and
helper implementation.

## Focused Chrome CI comparison

The focused A/B runs used the same two 16-vCPU system-test jobs, same test
selection, and pinned app source. Each run had two attempts; the table reports
both step durations and their mean. Native CDP included two driver-specific
examples, so its core count is two higher. The first direct-CDP core attempt
hit a transient WEBrick port collision and retried eight examples; all passed.
The second attempt and both core-plugins attempts had no retries.

| Job | Playwright attempts | Direct CDP attempts | Mean change | Test result |
| --- | ---: | ---: | ---: | --- |
| Core system | 508s, 505s (506.5s mean) | 446s, 428s (437s mean) | 13.7% faster | Playwright: 2,321 examples, 0 failures; CDP: 2,323 examples, 0 failures |
| Core-plugins system | 399s, 392s (395.5s mean) | 312s, 334s (323s mean) | 18.3% faster | Both: 1,568 examples, 0 failures |

On the second attempt, direct CDP also used less measured test-step CPU and
peak job-container memory:

| Job | Playwright CPU / peak memory | Direct CDP CPU / peak memory |
| --- | ---: | ---: |
| Core system | 5,904 CPU-s / 20,250 MiB | 4,982 CPU-s / 17,711 MiB |
| Core-plugins system | 4,621 CPU-s / 22,999 MiB | 3,894 CPU-s / 19,516 MiB |

The attempts had no observed CPU throttling or OOM events. Full job durations
were longer than the test-step durations because setup and teardown are
included outside the table above.

- [Playwright focused run, attempt 1](https://github.com/discourse/discourse/actions/runs/36308072975/attempts/1)
- [Playwright focused run, attempt 2](https://github.com/discourse/discourse/actions/runs/36308072975/attempts/2)
- [Direct-CDP focused run, attempt 1](https://github.com/discourse/discourse/actions/runs/36308763873/attempts/1)
- [Direct-CDP focused run, attempt 2](https://github.com/discourse/discourse/actions/runs/36308763873/attempts/2)

These runs show that the direct-CDP driver bundle improved the two focused
jobs. They do not isolate Rust as the cause: protocol choice, browser command
path, helper behavior, and the process bridge all differ from Playwright.

## Full-matrix result and limits

The complete ten-entry Tests workflow was restored for run
[36310250638](https://github.com/discourse/discourse/actions/runs/36310250638).
All five system-test groups passed. Core used direct CDP and took 499s for the
test step (2,323 examples, 0 failures); core-plugins took 331s (1,568 examples,
0 failures). Core's 499s was only 6–9s below the focused Playwright controls,
so the focused core improvement did not reproduce at the same size in this
single full-matrix run. Core-plugins was 5m31s, around 15–16% below the focused
Playwright controls, but that is not a matched full-matrix comparison.

The overall workflow was not green: the unrelated core backend RSpec job
reached its 20m08s timeout, and 9 of 10 build jobs succeeded. These data do not
prove an eight-minute end-to-end workflow.

## Why direct CDP looked faster than Rust BiDi in profiling

A one-example profile found a repeated remote-element-read cost, not a general
language-runtime advantage. On the instrumented about-page workload, both
drivers issued 74 CSS lookups, 101 visibility checks, 49 text reads, 44
attribute reads, and two clicks. Median command latency in milliseconds was:

| Operation | Rust BiDi | Rust direct CDP |
| --- | ---: | ---: |
| CSS lookup | 2.62 | 1.51 |
| Visibility check | 2.79 | 0.73 |
| Text read | 2.79 | 0.78 |
| Attribute read | 2.08 | 0.49 |

Across those repeated reads, the measured cumulative difference was about
0.45–0.46s, close to the roughly 0.49s whole-example gap in that workload.
Navigation and reset time were essentially tied. A same-WebSocket probe also
found lower latency for direct `Runtime.callFunctionOn` than BiDi
`script.callFunction`. This points to the command/reference/marshalling path
for repeated DOM reads as a plausible source of the difference. It is evidence
from one workload, not a suite-wide attribution.

The observation is not that BiDi always loses to Playwright: in this specimen,
Rust BiDi beat stock Playwright but was slower than optimized Playwright and
direct CDP. The CI A/B above compares Playwright with direct CDP, not BiDi.

## Browser coverage

Earlier work passed two Firefox system-spec smoke examples with Rust BiDi and
with Playwright; that is limited compatibility evidence, not a full Firefox
suite. Safari is out of scope. Chrome is the CI browser and is the subject of
the performance comparison.

## Ruby-driver experiment

The current evidence does not show whether Ruby can match the direct-CDP CI
performance. Since Capybara-facing behavior is already Ruby, the useful test is
to preserve that adapter and compare only the CDP process, transport, and
`Driver.*` helper layer. A direct Ruby transport could remove the
Ruby-to-subprocess hop and avoid the bridge's extra JSON decode/encode work;
Ruby's protocol parsing, event dispatch, and helper execution could also cost
more than the Rust implementation. That is a hypothesis, not a measured result.

The Ruby bridge has not yet produced a comparable timing because its focused
two-example run fails. In run
[36322976955](https://github.com/discourse/discourse/actions/runs/36322976955),
the Rust control made one internal `Target.getTargets` request before the
sample and passed both examples in 15s. The Ruby bridge made the same internal
request successfully, then its reader exited with `IOError` before the outer
`Target.getTargets` request (browser request ID 2) hit EPIPE; Ruby failed both
examples in 2.36s. Chrome remained alive and its descriptors still matched the
socket endpoints. The RSpec error then surfaced in `PlaywrightLogger#initialize`
when `NativeSystemDriver#on` tried to access `@page.callbacks` while `@page` was
nil. `start` currently treats `@input` as proof that browser initialization is
complete, even though `Open3.popen3` assigns it before the first page is ready.
That made a concurrent `start` call a plausible cause. The duplicate request
itself was not the trigger, but this run did not identify why Chrome closed
its endpoint.

Run [36323827643](https://github.com/discourse/discourse/actions/runs/36323827643)
tested a startup mutex. Rust passed the same two examples in 10.38s (15s for
the bridge command); Ruby still failed both in 2.44s. Its internal threaded
probe passed, but the reader exited with `IOError` before the external
`Target.getTargets` request (ID 2) hit EPIPE. CI recorded no overlapping
`start` call, so the partial-initialization race was not observed and the lock
did not resolve the transport failure. Rust clones its Unix socket for the
reader thread while Ruby shared one `Socket` object for reads and writes. The
next run tested separate duplicated handles, as described below.

Run [36324429524](https://github.com/discourse/discourse/actions/runs/36324429524)
tested separate Ruby socket handles. Rust passed both examples in 9.78s (14s
for the bridge command); Ruby still failed both in 2.39s. The Ruby probe
returned `RuntimeError`, and the reader again saw `IOError`/EOF before the
external `Target.getTargets` request (ID 2) hit EPIPE. Separate Ruby IO objects
did not match Rust's working behavior. The next run traces only
descriptor-management syscalls for the Ruby bridge and Chrome. The trace is
reduced to process labels and fd operations before entering the failure
message; it does not capture CDP reads or writes.

Run [36325081594](https://github.com/discourse/discourse/actions/runs/36325081594)
ran that descriptor trace. Rust passed the two examples in 10.94s (16s for the
bridge command); Ruby failed both in 3.41s. The Ruby threaded pipe probe passed,
but its reader then exited with `IOError`/EOF before the external
`Target.getTargets` request (ID 2) failed with EPIPE. The trace itself was
collected, but its first safe summary was capped across both processes and was
filled by repeated Ruby `close(5)=0` calls, hiding Chrome's fd 3/4 events. That
summary cannot establish which process closed the browser pipe. The next run
keeps Ruby and Chrome events separate and compresses repeated operations; it
still reports only process labels and selected descriptor-management calls.

Run [36325550883](https://github.com/discourse/discourse/actions/runs/36325550883)
used the grouped trace. The workflow's first sample (Rust) passed in 10.22s;
the second sample (Ruby) failed both selected examples in 3.46s. Five bridge
traces were present. Across them Ruby had close/fcntl activity on its two
tracked descriptors; Chrome's launch process had only the expected dup2/fcntl
setup for descriptors 3 and 4 and no close calls. The reported socket endpoints
still matched at failure time. Each Ruby bridge `IOError` marker came after the
first RSpec failure marker, so the pipe EOF is consistent with teardown but is
not established as the initiating cause. The first failure was the about-page
admin expansion example, a `NoSuchWindowError` re-raised while waiting for a
command response. The next focused run isolates the native stale-element
example and emits only the output-reader exception class and a source
file/line if that reader fails.

Earlier two-request pipelined Ruby probes were inconsistent, sometimes
receiving only one response. They have been removed so the focused sample now
uses only one threaded probe. Until Ruby passes the same focused examples,
there is no Ruby performance measurement and Rust remains the only measured
direct-CDP bridge. Firefox remains a functional compatibility check; Safari
will not be tested.
