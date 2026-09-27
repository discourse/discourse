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

Run [36335885721](https://github.com/discourse/discourse/actions/runs/36335885721)
at head `046ce4b0ef9` added the matched two-command probe. Ruby syntax passed.
The Rust one-example sample passed in 4.17s (4.07s load). The Ruby probe
reported an `IOError`; its safe sequence was internal `Target.getTargets`
send/response, then internal `Target.getTargetInfo` send with no response,
followed by the Capybara startup request failing on the closed pipe. The
reader saw Chrome's pipe EOF before that write failure. This isolates the
failure to the Ruby bridge's second browser command, before Capybara can
attach the page. The Rust probe marker was not retained in the extracted log,
though its sample passed. This diagnostic run is not a performance result.
The next run adds safe close-on-exec state and traces only descriptor
close/shutdown operations during the Ruby probe to identify who closes the
pipe.

Run [36336471603](https://github.com/discourse/discourse/actions/runs/36336471603)
at head `31d6809b1fc` reproduced the same failure with the descriptor trace
enabled. Rust passed the one-example sample in 3.96s (4.50s load); Ruby failed
in 2.36s (3.22s load), and Ruby syntax passed. The Ruby probe again got no
`Target.getTargetInfo` response. Both Chrome descriptors were sockets with
read-write access, matched the spawned endpoint, and had close-on-exec unset.
The trace shows Chromium calling `shutdown(SHUT_RDWR)` on both fd3 and fd4;
there is no evidence of a missing inherited descriptor. The trace summary
doesn't establish what triggered Chromium's shutdown. The next experiment
removes Ruby's duplicate writer descriptor and uses the same socket object for
both the reader thread and serialized writes, to isolate Ruby's duplicated-fd
handling.

Run [36337232690](https://github.com/discourse/discourse/actions/runs/36337232690)
at head `50e9d5453e1` tested the shared Ruby socket object. Ruby syntax passed;
Rust passed the focused example in 3.38s, and Ruby failed it in 2.19s. The
safe Ruby sequence was internal `Target.getTargets` send/response, internal
`Target.getTargetInfo` send with no response, then forwarded `Target.getTargets`
send before EPIPE. The reader exited with `IOError` before that forwarded
write; this was pipe closure, not a protocol error response or the 30-second
timeout. There was no parent output-reader exception or surfaced Chrome
startup error. The trace includes Chrome-side shutdown, but its summary drops
timestamps, so it cannot establish which command caused that shutdown. Sharing
the IO object did not change the failure and produced no Ruby performance
measurement. The next matched probe requests `Target.getTargets` twice before
`Target.getTargetInfo`; this distinguishes a generic second-command failure
from a method-specific issue. Ruby's separate reader/writer handles are
restored.

Run [36338246326](https://github.com/discourse/discourse/actions/runs/36338246326)
at head `bb4801b6b49` repeated `Target.getTargets` before `Target.getTargetInfo`
in both bridges. Rust passed the focused example in 3.77s. Ruby failed in
2.24s: its first internal `Target.getTargets` received a response, but the
second received none; the reader then observed EOF, and the later forwarded
`Target.getTargets` write failed. This rules out `Target.getTargetInfo` as a
special case and confirms that reusing a single Ruby IO object was not the
cause. No Ruby performance result is available. The next diagnostic performs
two synchronous Ruby request/response cycles before starting the reader and
worker threads. If that succeeds, it isolates the failure to the threaded Ruby
transport path; if it fails, the problem remains in the Ruby wire or browser
launch path.

Run [36338911261](https://github.com/discourse/discourse/actions/runs/36338911261)
at head `6317959c7c8` ran those two synchronous Ruby calls before starting any
threads. Ruby syntax passed; Rust passed the focused example in 3.47s, while
Ruby failed in 2.27s. The Ruby sequence was internal `Target.getTargets`
send/response, a second internal send with no response, then a forwarded send
with no response. This rules out the Ruby reader thread and response queue as
the trigger, and the repeated method rules out a method-specific issue. The
reported synchronous probe error was an `Errno` failure, but its stage and
fully qualified error class were not retained, so this run cannot yet tell
whether the second JSON write, delimiter write, or response read failed. The
next run aligns Ruby's original/duplicated socket roles with Rust's original
writer and cloned reader, and records only write byte counts, attempt number,
stage, and exception class.

Run [36339974189](https://github.com/discourse/discourse/actions/runs/36339974189)
at head `9329ae16be7` tested that socket-role alignment. Rust passed the
focused example in 3.61s; Ruby failed in 2.17s, so no Ruby performance result
is available. The socket change is inconclusive because the probe's rescue
path raised `NameError` before it could report the failing stage. Ruby syntax
passed. The source initializes `write_stage` and the byte counters inside the
`2.times` block, then interpolates them in the method-level rescue; the log
omits the NameError message, so this is the likely instrumentation fault. The
next commit moves their initialization to method scope and reruns the same
transport experiment without changing its wire behavior. Linting still reports
`syntax_tree` failures for the two modified Ruby files, but CI exposes only the
paths and not the expected formatting.

Run [36340441736](https://github.com/discourse/discourse/actions/runs/36340441736)
at head `b5662d4114b` reran the probe with the rescue variables in method scope.
Rust passed the focused example in 3.36s; Ruby failed in 2.14s. Its safe
diagnostic was `Errno::EPIPE` on attempt 2 at the JSON write, with zero JSON
bytes and zero delimiter bytes written. Thus the peer had closed its read end
before Ruby began the second request; aligning Ruby's original/cloned socket
roles with Rust did not prevent it. Ruby syntax and Linting passed. The next
run records whether Chrome had exited and compares Chrome's pipe-shutdown
timestamp with Ruby's failed-write time, distinguishing browser-side closure
from shutdown during test cleanup.

Run [36341041478](https://github.com/discourse/discourse/actions/runs/36341041478)
at head `95dd9d0180a` found Chrome still alive when Ruby caught the second-write
`EPIPE`; Chrome had shut down its pipe before the diagnostic marker was
written. That ordering is suggestive but not conclusive because the marker is
emitted after the failed syscall. The next run traces only outgoing write
syscalls in raw-argument mode, so the local trace does not record protocol
contents; the reducer compares the exact `EPIPE` syscall time with Chrome's
shutdown time and publishes only which came first. Linting again failed at
`syntax_tree` without line-level formatting output.

Run [36341433194](https://github.com/discourse/discourse/actions/runs/36341433194)
at head `fc6a7104899` found Chrome still alive at Ruby's second-write failure.
The traced Chrome `shutdown` preceded the traced Ruby `EPIPE`, but this does
not explain what triggered Chrome's shutdown. The available Chrome EOF marker
is ordered before the later forwarded-write failure, not precisely against
the earlier synchronous probe failure; no Ruby-side `shutdown` syscall appears
on either tracked socket handle. Chromium's current
[`DevToolsPipeHandler`](https://chromium.googlesource.com/chromium/src/+/main/content/browser/devtools/devtools_pipe_handler.cc)
logs the pipe-reader EOF when `read()` returns no bytes and then shuts down
both pipe ends, so that shutdown can be a response to peer EOF rather than its
cause. The next run traces raw-argument `read` syscalls and compares Chrome's
actual zero-byte read with closes of both Ruby socket handles; only event-order
booleans are emitted. Rust passed in 3.37s and Ruby failed in 2.26s. Linting
again failed only at `syntax_tree`.

Run [36342322053](https://github.com/discourse/discourse/actions/runs/36342322053)
at head `33d7deb8fe2` passed the Rust focused example in 3.22s; Ruby failed in
2.20s with `Errno::EPIPE` on attempt 2, before writing any JSON bytes, while
Chrome was still alive. The trace reducer reported the Chrome EOF and Ruby
endpoint ordering as unknown. Luna's review confirmed the reducer only opened
the root Ruby and Chrome trace files, even though `strace -ff` writes separate
files for traced tasks. Since the workflow removes the temporary trace files
and keeps no artifact, this run cannot establish whether the relevant read was
absent or recorded under a Chrome thread. The next run captures Chrome's task
IDs privately during the focused probe and scans those task traces, emitting
only event-presence and ordering labels. No protocol payloads, task IDs,
descriptor numbers, or raw trace lines are added to CI output. Linting failed
at `syntax_tree` for both modified Ruby files.

Run [36343320451](https://github.com/discourse/discourse/actions/runs/36343320451)
at head `01d144b7d43` passed the Rust focused example in 3.34s and failed the
Ruby focused example in 2.26s with the same second-write `Errno::EPIPE`.
Sampling Chrome's task IDs during the probe and scanning those traces still
found no zero-byte `read` on the expected pipe descriptors. At the failed
write, both Chrome descriptors still matched the spawned socket endpoint and
were read-write with close-on-exec disabled; the Ruby writer remained open and
matched its endpoint. The method sequence was first internal send/response,
second internal send without a response, then forwarded send. No Chrome
protocol-error or crash message was captured. Both Ruby endpoint closes were
observed only in teardown, with no writer shutdown; because there is no Chrome
EOF timestamp, the run cannot order the closes against Chrome's pipe shutdown.
The reducer only recognizes `read` syscalls returning zero, so it could miss
socket receive calls or failed reads. The next probe includes `readv`,
`recvfrom`, and `recvmsg` without dumping buffer data, and reports only
whether a matching read, zero-return read, or failed read was observed. It
also uses a non-consuming socket peek to classify Chrome's output side as
open, containing data, or EOF immediately before each request. Trace files and
task IDs remain temporary and are removed after the check. Linting failed at
`syntax_tree` for both modified Ruby files.

Run [36344186816](https://github.com/discourse/discourse/actions/runs/36344186816)
at head `340dc32e7cd` passed the Rust focused example in 3.41s and failed the
Ruby example in 2.32s with `Errno::EPIPE` on its second synchronous request,
before writing any JSON or delimiter bytes. The trace found a zero-byte Chrome
read before the failed Ruby write, while both Ruby socket handles closed only
later during teardown; Chrome's shutdown was also before the write failure.
This narrows the failure to Chrome having already seen EOF or stopped using
the command stream, not a Ruby-side close recorded on the tracked handles. The
trace merged Chrome's command-input and response-output descriptors, however,
so it did not yet identify which side read EOF. The peer-state probe also
reported `unknown`; its Ruby code did not classify a `nil` result as EOF.
Chromium documents fd 3 as the remote-debugging command input and fd 4 as the
response output ([source](https://chromium.googlesource.com/chromium/src/+/e972c575b9a075ab5dcadddf269d60bb23d4af35)). The next run separates read
events for those roles, handles both `nil` and empty-string EOF results, and
records the peer state immediately before the second write. The run still
provides no Ruby performance measurement because the bridge fails before
completing the focused example. The Linting job failed SyntaxTree for the two
modified Ruby files; other reported linters passed
([run](https://github.com/discourse/discourse/actions/runs/36344186781)).

Run [36344928380](https://github.com/discourse/discourse/actions/runs/36344928380)
at head `0af372cd6ba` passed the Rust focused example in 3.33s and failed the
Ruby example in 2.07s with `Errno::EPIPE` on the second synchronous request,
before writing any bytes. Separating Chrome's pipe roles showed a zero-byte
read on its command-input stream before Ruby's `EPIPE`; Chrome made no reads on
the response-output descriptor. Ruby's post-error peek saw EOF, both tracked
Ruby socket handles closed later during teardown, and Chrome shutdown preceded
the failed write. This confirms that Chrome stopped receiving commands before
Ruby's tracked handles were closed, but does not yet identify what made the
command-input stream reach EOF. The peer state immediately before the second
write was not included in the failure summary: the summary parser's key-name
pattern excluded the digit in that field. The next run fixes that allowlist
parser so the state can distinguish whether EOF was already visible before the
write. No Ruby performance timing is available because the Ruby example still
fails. Linting again failed SyntaxTree on both modified Ruby files
([run](https://github.com/discourse/discourse/actions/runs/36344928366)).

Run [36345458646](https://github.com/discourse/discourse/actions/runs/36345458646)
at head `cd403ada4e8` passed the Rust sample and failed the Ruby sample. The
fixed summary parser now shows that Ruby already saw peer EOF before attempt 2
and still saw EOF after the failed write. Chrome read EOF on its command-input
stream, had no reads on its response-output descriptor, and returned exactly
one internal response before the command stream closed. Both Ruby socket
handles were closed only later during teardown. This places the disconnect
after the first successful response and before Ruby's next send; it is not
caused by attempt 2's payload. The CI output omitted the successful first-write
byte counts because the failure summary only retained attempt 2. The next run
will preserve the first request's byte counts and sample peer state immediately
after its response to pin down the transition boundary. No Ruby performance
timing is available. Linting still fails SyntaxTree for both modified Ruby
files ([run](https://github.com/discourse/discourse/actions/runs/36345458624)).
