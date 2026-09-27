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

Run [36327409327](https://github.com/discourse/discourse/actions/runs/36327409327)
isolated that native stale-element example. Rust passed one example in 3.24s;
Ruby failed one in 2.10s. The Ruby failure stack reached the bridge's EPIPE
rescue at `ruby/bridge.rb:205`, while Chrome was still alive; the parent
output-reader error marker was absent. The CI extraction did not retain the
failed CDP method or pipe-state booleans, so the failed command remains unknown.
The next run maps one Ruby socket descriptor to both Chrome pipe fds, matching
the Rust launch setup more closely, and attempts to emit the method, write
stage, and sanitized descriptor state in a dedicated marker.

Run [36328236106](https://github.com/discourse/discourse/actions/runs/36328236106)
used that fd mapping and isolated the same one-example sample. Rust passed in
3.34s; Ruby failed in 2.10s at the bridge's EPIPE rescue while Chrome's pipe
reader thread was already stopped. The CI summary identified the first write
stage as JSON, but did not retain the dedicated pipe-write or reader-exit
markers or the Chrome fd booleans. This still gives no Ruby performance result
and does not explain why Chrome closed its endpoint. The next change puts the
safe method, write stage, Chrome-alive flag, and reader-exit class/frame into
the generic bridge failure record, which CI did capture, and omits the request
ID from that diagnostic.

Run [36329344348](https://github.com/discourse/discourse/actions/runs/36329344348)
captured those fields. Rust passed the one-example sample in 3.36s; Ruby failed
in 2.24s when `target.click` surfaced a `RuntimeError` categorized as a closed
browser pipe. The later `Page.captureScreenshot` no-page error and reader EOF at
`bridge.rb:146` followed the first RSpec failure, so they are cleanup symptoms.
At the later EPIPE, Chrome remained alive and its fd 3/4 socket endpoints still
matched the launch endpoints. The original pipe closure remains unexplained
because the previous run's fd trace was only attached to bridge-process exit,
not this first command failure. The next run attaches the existing fd-only
trace summary at the first pipe error.

Run [36330866576](https://github.com/discourse/discourse/actions/runs/36330866576)
at head `6bf28650107` captured that summary. Rust passed the one-example
sample in 3.39s (4.09s RSpec load); Ruby failed in 2.25s (2.96s load). The
closed-pipe error reported the JSON write stage, but the extracted failure did
not retain a CDP method name and Chrome stderr had no diagnostic. Chrome was
still alive, and its fd 3/4 sockets had shutdown calls in the descriptor trace;
the Ruby reader EOF was recorded before the later write failure. This narrows
the failure to the debug-pipe lifecycle but does not identify its initiating
command. The screenshot/no-page errors followed the first RSpec failure. The
next attempt emits a separate sanitized method/stage marker at the first
EPIPE, without protocol payloads or request identifiers.

Run [36332071572](https://github.com/discourse/discourse/actions/runs/36332071572)
at head `b2a4a34a9c5` passed the Ruby syntax check. Rust passed the one-example
sample in 3.86s (4.09s RSpec load); Ruby failed in 2.21s (2.96s load). The
new marker identified `Target.getTargets`, stage `json`, with Chrome still
alive. This is a startup command, but the Ruby sample also had a CI-only
self-probe that uses the same method, so the failing request's source was
ambiguous. The run did not produce a Ruby performance measurement. The next
attempt removes that self-probe from both driver samples, leaving the ordinary
Capybara startup command as the first browser request.

Run [36332535124](https://github.com/discourse/discourse/actions/runs/36332535124)
at head `b6d2833cd20` removed the self-probes. Ruby syntax passed. Rust passed
the sample in 3.37s (4.06s RSpec load); Ruby failed in 2.45s (2.97s load).
The first Ruby pipe failure moved to `Target.getTargetInfo` at JSON-write
stage, with Chrome still alive. This comes from the `Driver.attachPage` helper
after the ordinary `Target.getTargets` request has returned, so the Ruby
transport completes at least one startup round trip before it fails. No Ruby
performance measurement is available. The next trace records only the last
eight CDP method send/response/event names and whether a failed request was
forwarded or internal, to identify the sequence immediately before the pipe
closes.

Run [36332945179](https://github.com/discourse/discourse/actions/runs/36332945179)
at head `a7c57f88c6c` passed Ruby syntax. Rust passed the one-example sample
in 3.32s (4.01s RSpec load); Ruby failed in 2.13s (2.89s load). The Ruby
marker reports `Target.getTargetInfo`, `origin=internal`, JSON-write stage,
and Chrome alive. Its method trace is `send:Target.getTargets`,
`response:Target.getTargets`, then `send:Target.getTargetInfo`: the browser
answered the first request before the helper's attach request hit EPIPE. The
descriptor trace shows `SHUT_RDWR` on Chrome fds 3 and 4 by the failure. This
localizes the difference to early attach startup, but still does not explain
why Chrome shuts down the Ruby bridge's pipe. There is still no Ruby
performance measurement. The fd trace used `strace` only for the Ruby sample,
so the next run removes that wrapper while retaining the safe method sequence;
this tests whether tracing itself contributes to the early shutdown.

Run [36333552920](https://github.com/discourse/discourse/actions/runs/36333552920)
at head `64b10a6d772` removed the `strace` wrapper. Ruby syntax passed. Rust
passed the sample in 3.54s (3.98s RSpec load); Ruby failed in 1.24s (2.83s
load). The Ruby marker moved back to a forwarded `Target.getTargets` JSON
write, with Chrome alive. Its recent sequence was two `send:Target.getTargets`
events and no response between them. The failure point therefore changes with
tracing, but Ruby still fails without it. The duplicate sends suggest
concurrent submissions; Ruby then protected request bookkeeping and wire
writes with separate mutexes, while Rust made ID allocation, pending
registration, and the write one atomic operation. The next run aligned Ruby's
submit locking with Rust and labeled the origin on each safe sequence event.

Run [36334148081](https://github.com/discourse/discourse/actions/runs/36334148081)
at head `b542a46989b` tested that atomic submit. Ruby syntax passed. Rust
passed the sample in 3.29s (4.20s RSpec load); Ruby failed in 1.25s (2.99s
load). Ruby still emitted two forwarded `Target.getTargets` sends without a
response before EPIPE, so atomic submit did not resolve the failure. The next
run added an initialization wait gate and marker to check whether another
browser command was arriving before startup finished.

Earlier two-request pipelined Ruby probes were inconsistent, sometimes
receiving only one response. Until Ruby passes the same focused system-test
sample, there is no Ruby performance measurement and Rust remains the only
measured direct-CDP bridge. Firefox remains a functional compatibility check;
Safari will not be tested.

Run [36334731221](https://github.com/discourse/discourse/actions/runs/36334731221)
at head `6764eab6ef6` tested the startup wait gate. Ruby syntax passed; Rust
passed the one-example sample in 3.31s (3.95s RSpec load), while Ruby failed in
1.35s (2.93s load). The wait marker was absent, so the sample did not exercise
the gate, and the same internal `Target.getTargetInfo` write still failed
after a forwarded `Target.getTargets` response. The Ruby reader saw EOF before
the failed write even though its writer remained open; Chrome fd3/fd4 were
read-write sockets matching the spawned endpoints. This disproves startup
overlap as the cause for this failure. The next run removes the gate and adds
matched two-command `Target.getTargets` → `Target.getTargetInfo` probes to the
Rust and Ruby bridges. That distinguishes Ruby's consecutive internal calls
from the Capybara-forwarded startup sequence. No Ruby performance measurement
is available yet.
