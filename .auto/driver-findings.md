# System-test driver findings

Updated 2026-09-28. Measurements below compare the existing Playwright-backed
Capybara driver with the native direct-CDP driver on the pinned application
source revision `bf55a44c2872738f7ae2664d6fec3d6d8779190f`. Timings are elapsed
seconds for the system-test step unless marked otherwise. These are aggregate
CI measurements; raw logs and profiles remain local.

## Trace parsing correction (2026-09-28)

The descriptor probe uses `strace -e raw=...` to avoid recording protocol
payloads. A synthetic pipe trace showed that this mode prints syscall return
values such as `0x31` in hexadecimal. The reducer accepted only decimal digits,
so it read positive results as zero, misclassified successful Chrome reads as
EOF, and reported zero byte counts. Trace-derived read EOF/error, byte-count,
and event-order conclusions from runs starting at
[36344186816](https://github.com/discourse/discourse/actions/runs/36344186816)
through [36348945466](https://github.com/discourse/discourse/actions/runs/36348945466)
are therefore not reliable. The Ruby bridge's separate diagnostics—successful
request writes, a response received, EOF seen by Ruby, pipe identity, and
Chrome's process exit state—are independent of that parser and remain valid.
The reducer now parses decimal and hexadecimal results. A local synthetic pipe
confirmed that the updated matcher reads `0x31` as 49 bytes, `0` as EOF, and
`-1 EPIPE` as an error. Ruby syntax, formatting, and diff checks pass; a new
focused CI run is needed before using syscall-level counts to explain the
disconnect.

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

Run [36346335934](https://github.com/discourse/discourse/actions/runs/36346335934)
at head `b2fd2708fb6` passed the Rust sample and failed the Ruby sample. The
Ruby sync probe fully wrote its first 49-byte JSON command and NUL delimiter,
received and validated a response, then saw peer EOF before attempting command
two. The Chrome command-input trace recorded EOF; the response-output
descriptor had no reads. Both Ruby handles closed after Chrome EOF, and no
Ruby writer shutdown was observed. This confirms the failing second write only
exposed an already-closed peer. It does not identify what caused the closure.
Linting passed. There is still no Ruby timing.

Run [36347597995](https://github.com/discourse/discourse/actions/runs/36347597995)
at head `d81a124d895` changed the Ruby sample to use the two one-way pipes
expected by `--remote-debugging-pipe`. Rust passed its focused example in
3.51s. Ruby fully wrote two 49-byte JSON commands and their delimiters and
received the first response, then got EOF while waiting for the second; Chrome
was already exited. Its 2.49s sample ended in failure and is not a valid timing.
The job log contained no known Chrome pipe diagnostic or fatal/error category,
and exposed no exit code or signal. The trace still places Ruby endpoint closes
after Chrome input EOF; separate-pipe transport therefore changed the failure
from an early EPIPE to a missing second response but did not make Ruby viable.
Linting passed. The next probe records Chrome's exit status and verifies both
mapped Chrome pipe roles and Ruby's command writer immediately after response
one, using only safe booleans and access labels.

Run [36348418411](https://github.com/discourse/discourse/actions/runs/36348418411)
at head `223a0cac539` confirmed the pipe mapping immediately after the first
response: Chrome fd3 matched the read end, fd4 matched the write end, both had
the expected access and no close-on-exec flag, and Ruby's reader and writer
were open with the writer still matching the input pipe. Ruby wrote command two
and its delimiter, then got EOF waiting for the response. After that error the
Ruby writer remained open and matched the input pipe; Chrome had exited
normally (`exit_0`) and its descriptors were gone. No Ruby timing is valid;
Rust passed in 3.39s and Ruby failed in 2.37s. Linting passed. This rules out
the simple wrong-fd mapping or early Ruby-writer-close explanations, but the
trace still does not show whether Chrome consumed command two. The next probe
counts command bytes read by Chrome and response bytes written by Chrome, plus
the matching Ruby-side byte counts, without retaining payloads.

Run [36348945466](https://github.com/discourse/discourse/actions/runs/36348945466)
at head `905341794cc` passed the Rust focused example in 3.18s and failed the
Ruby example in 2.31s, so it provides no Ruby timing. Linting passed. The
instrumentation printed zero syscall byte counts, but that output is invalid:
the trace reducer parsed raw hexadecimal return values as decimal. The
independent Ruby probe still confirms its second request was written before it
read EOF, and Chrome exited normally; the syscall-level counts and EOF
classification require a rerun with the corrected reducer.

Run [36349742578](https://github.com/discourse/discourse/actions/runs/36349742578/job/108705968817)
at head `343451393b9` passed the Rust focused example in 3.33s and failed the
Ruby probe in 2.27s, so it provides no Ruby performance timing. Linting passed
([job](https://github.com/discourse/discourse/actions/runs/36349742615/job/108705968991)).
With the corrected parser, Ruby wrote 100 command bytes; Chrome read 50 bytes,
then wrote 236 response bytes in two calls; Ruby read the same 236 bytes in one
call. The probe failed at the second response read. The counters establish that
Chrome produced output and Ruby received it, but they do not show how many
NUL-framed messages Ruby decoded or whether a response matched request two.
The next probe reports only per-attempt message counts and event, matching
response, unmatched response, and error-response counts. It emits no IDs or
protocol contents.

Run [36350257744](https://github.com/discourse/discourse/actions/runs/36350257744)
at head `49654edbdc8` passed the Rust focused example in 3.18s and failed the
Ruby probe in 2.35s; Ruby still has no valid timing. Linting passed. The frame
counts show one matching response to attempt one and no messages for attempt
two. The corrected trace recorded one 50-byte Chrome input read against 100
Ruby command bytes written, and one 236-byte response received by Ruby. Chrome
was alive with the expected input/output endpoints after response one, then
exited cleanly before the probe completed; Ruby's input writer remained open.
This rules out a response-framing or response-ID mismatch in Ruby and points
to the browser process exiting before consuming command two. The next focused
run switches Ruby from two pipes to the Unix socket pair used by the Rust
bridge, holding the test and synchronous two-command probe fixed.

Run [36351012213](https://github.com/discourse/discourse/actions/runs/36351012213)
at head `24eca91d952` passed the Rust focused example in 3.32s and failed the
Ruby socket-pair probe in 2.19s, so there is still no valid Ruby timing. Chrome
read Ruby's first 50-byte command and returned one 235-byte response; Ruby saw
peer EOF after that response and before attempting command two. Chrome remained
alive with fd3/fd4 mapped to the expected socket endpoint and open. Its fd3
read returned an error, and its two shutdown calls preceded Ruby's later
`EPIPE`. The socket-pair topology used by Rust therefore does not by itself
resolve the Ruby startup failure. The next probe retains only an allowlisted
errno category and whether the first Chrome read error preceded or followed
the first response. Raw syscall traces and timestamps remain unreported.

Run [36351817677](https://github.com/discourse/discourse/actions/runs/36351817677)
at head `e6e17336f8b` passed the Rust sample in 3.55s and failed the Ruby probe,
so Ruby still has no valid performance timing. The new safe trace category is
`EAGAIN`, with the first Chrome fd3 read error timestamped before Ruby received
response one. Chromium retries `EINTR`, but treats other non-positive reads as
a disconnected DevTools pipe and shuts both ends down ([pipe handler source](https://chromium.googlesource.com/chromium/src/+/main/content/browser/devtools/devtools_pipe_handler.cc)).
A local Ruby 3.3 check found `O_NONBLOCK` set on newly created `IO.pipe`,
`Socket.pair`, and `UNIXSocket.pair` endpoints; a spawned child inherits the
flag, and clearing it on the child endpoint makes the inherited descriptor
blocking. The Rust bridge creates a `UnixStream` pair without enabling
nonblocking mode. This explains why both Ruby transports failed after one
command while the Rust transport remained connected. The next focused run
clears nonblocking mode only on the descriptors passed to Chrome and checks
whether Ruby can complete the two-command probe.

Run [36352469718](https://github.com/discourse/discourse/actions/runs/36352469718/job/108713649027)
at head `15998d4a5b0` passed both focused samples; Linting also passed
([job](https://github.com/discourse/discourse/actions/runs/36352469702/job/108713648882)).
The Rust sample took 3.42s in RSpec and 7s for its bridge command. Ruby took
5.06s in RSpec and 9s for its bridge command. Ruby now stays connected through
the sample after the Chrome-side descriptors are made blocking, consistent
with the `EAGAIN` diagnosis. These timings are not a valid speed comparison
because Ruby was still wrapped in `strace`. The following untraced run used the
stale-element and unload-confirmation examples, retaining the two-command probe
to check transport setup; its results follow.

Run [36352957242](https://github.com/discourse/discourse/actions/runs/36352957242/job/108715019081)
at head `810e6f4c441` passed both focused samples; Linting passed
([job](https://github.com/discourse/discourse/actions/runs/36352957230/job/108715019056)).
With tracing disabled, Rust completed the stale-element and unload-confirmation
examples in 3.50s, while Ruby completed them in 3.49s; each sample had two
examples and zero failures. Both bridge commands reported 7s at whole-second
resolution. The focused Ruby/Rust difference is effectively zero for these
flows, but browser/test setup dominates this short sample. The next run uses
one CI-only example with 500 sequential `page.evaluate_script` calls and records
only operation count and elapsed milliseconds to isolate repeated CDP
round-trip cost.

The transport failure was caused by nonblocking descriptors inherited by
Chrome. Ruby 3.3 creates the pipe and socket-pair endpoints used by the bridge
with `O_NONBLOCK`; Rust's `UnixStream::pair` leaves its endpoints blocking. The
Chrome-side Ruby descriptors now have nonblocking mode cleared before launch,
matching the Rust transport behavior. This allows the Ruby bridge to complete
the same focused system examples. The details are confirmed by Chromium's
DevTools pipe handler, which treats a non-positive read other than `EINTR` as a
disconnect, and by a local Ruby 3.3 descriptor check.

Run [36353533895](https://github.com/discourse/discourse/actions/runs/36353533895)
at head `4e717bd2a8b` passed the single 500-evaluation example for both
bridges, along with the Core System Tests job; the separate Linting job passed
([job](https://github.com/discourse/discourse/actions/runs/36353533928/job/108716663221)).
Rust completed the RSpec example in 3.56s and Ruby in 3.51s. The inner loop
reported 174.133ms for the first bridge and 137.000ms for the second, an
apparent 21.3% Ruby advantage. The workflow ran Rust first and Ruby second,
and the benchmark line did not yet include the bridge name, so this is only
an order-sensitive preliminary result. Whole-second bridge command times were
8s for Rust and 7s for Ruby. The next run reversed the order and labeled each
measurement, with tracing disabled; its result follows.

Run [36354299372](https://github.com/discourse/discourse/actions/runs/36354299372/job/108718821347)
at head `92543b7cb02` reversed the order and passed the same one-example,
500-evaluation sample for each bridge. Ruby ran first and measured 819.487ms;
Rust ran second and measured 984.033ms, an apparent 16.7% Ruby advantage. The
RSpec examples took 6.16s for Ruby and 5.70s for Rust, so total example startup
favored Rust by 0.46s. The per-loop results keep pointing to Ruby at least
matching Rust, but both loop measurements were about five times the prior
run's values (137.000ms and 174.133ms). This variation and the opposite RSpec
ordering result make a single pair too noisy for a conclusion. The separate
[Linting job](https://github.com/discourse/discourse/actions/runs/36354299364/job/108718821102)
was queued at the time of inspection; local targeted DV lint passed.

Run [36354911319](https://github.com/discourse/discourse/actions/runs/36354911319/job/108720609737)
at head `b07b1957f60` passed all four one-example runs in the order
Ruby/Rust/Rust/Ruby. The 500-call measurements were 465.884ms and 623.399ms
for Ruby, and 557.389ms and 396.746ms for Rust. Their two-sample means were
544.642ms for Ruby and 477.068ms for Rust, nominally 12.4% faster for Rust;
however, each driver's two samples varied by over 150ms, and the apparent
winner flipped between the first and second pair. RSpec times were 4.92s and
5.10s for Ruby, and 4.90s and 4.39s for Rust. [Core System Tests passed](https://github.com/discourse/discourse/actions/runs/36354911319/job/108720609737)
and [Linting passed](https://github.com/discourse/discourse/actions/runs/36354911298/job/108720610922).
The focused Core System Tests step used 40.135 CPU-seconds over 44 elapsed
seconds; this aggregate does not separate CPU use by bridge.

This microbenchmark keeps the Capybara-facing Ruby `NativeSystemDriver` and
Chrome page code fixed; with `NATIVE_CDP_DIRECT_EVAL=1`, each evaluation uses
one `Runtime.evaluate` request. Only the bridge process changes between the
Ruby and Rust samples.

Run [36355598699](https://github.com/discourse/discourse/actions/runs/36355598699/job/108722579777)
at head `9ddcc6261f7` passed the four benchmark examples after 100 warm-up
evaluations and five timed 500-call batches each. In Ruby/Rust/Rust/Ruby order,
the Ruby medians were 131.332ms and 144.787ms; Rust medians were 159.428ms and
159.694ms. The mean of each bridge's two per-run medians was 138.060ms for
Ruby and 159.561ms for Rust, a 13.5% lower Ruby latency for this direct
`Runtime.evaluate` workload. Rust's median was nearly identical across its two
runs; Ruby's second median was 10% higher than its first. Individual batches
contained occasional high outliers, so the medians are more useful than any
single batch. The RSpec example took 4.38s and 4.35s for Ruby, versus 4.15s
and 4.19s for Rust, meaning full example setup still favored Rust by about
0.20s per run. The inner-loop result therefore does not establish which bridge
would finish a full suite faster. The Core step used 40.135 CPU-seconds over
44 elapsed seconds in the preceding ABBA run; it does not attribute CPU or
memory to individual bridges. The current Core job used 26.860 CPU-seconds over
33 elapsed seconds and reported 5,893.42 MiB peak container memory across both
drivers and their Chrome sessions, also not attributable to either bridge
alone. [Linting passed](https://github.com/discourse/discourse/actions/runs/36355598687/job/108722579752).

The next run retains the warm-up and batch medians and adds one existing
representative user flow: expanding and collapsing the About page admin list
([spec](https://github.com/discourse/discourse/blob/bf55a44c2872738f7ae2664d6fec3d6d8779190f/spec/system/about_page_spec.rb#L215)).
The same one-example flow will run in each of the four order-balanced bridge
invocations. Its example duration will tell us whether Ruby's lower raw
round-trip latency carries through Capybara's locator and interaction helpers.

Run [36356240591](https://github.com/discourse/discourse/actions/runs/36356240591/job/108724423183)
at head `34408e245a4` passed both selected examples in each of the four
Ruby/Rust/Rust/Ruby invocations. The five-batch medians were 102.221ms and
132.129ms for Ruby, and 175.250ms and 157.215ms for Rust; the mean of per-run
medians was 117.175ms for Ruby and 166.233ms for Rust, or 29.5% lower latency
for Ruby on this repeated `Runtime.evaluate` workload. The RSpec invocation
times for the two examples together were 11.67s, 8.13s, 9.13s, and 8.05s in
that order. The large variation and the fact that the second invocation in
each adjacent pair was faster suggest that shared app/browser cache or runner
state materially affects the whole-example times; the log did not report each
example's duration separately. The Core step used about 49.37 CPU-seconds over
51 elapsed seconds and peaked at 5,811.23 MiB for the whole job/container.
These resource totals are not per bridge. [Linting passed](https://github.com/discourse/discourse/actions/runs/36356240588/job/108724423072).

Run [36356722884](https://github.com/discourse/discourse/actions/runs/36356722884/job/108725813132)
at head `5de1e80bc2a` passed both examples for each bridge; [Linting passed](https://github.com/discourse/discourse/actions/runs/36356722910/job/108725813240).
The focused results were:

| Bridge run | 500-call median | About-page example | Benchmark example | RSpec total |
| --- | ---: | ---: | ---: | ---: |
| Ruby 1 | 97.003ms | 6.44s | 3.91s | 10.55s |
| Rust 1 | 154.220ms | 4.00s | 3.96s | 8.09s |
| Rust 2 | 159.603ms | 3.86s | 3.94s | 7.92s |
| Ruby 2 | 108.053ms | 8.12s | 0.93s | 9.18s |

The two-run means show Ruby's simple `Runtime.evaluate` batch at 102.528ms,
34.7% below Rust's 156.912ms. The About-page flow averaged 7.28s in Ruby and
3.93s in Rust, while total RSpec time averaged 9.87s versus 8.01s. The browser
flow therefore reverses the simple-call result, with Rust about 46% faster in
this example. This points to work in element lookup/click helpers or their
command pattern, rather than raw browser round trips. The four RSpec totals
also vary with order; the profile split is useful here because it consistently
shows the About-page example slower in Ruby in both Ruby runs. The Core step
used about 47.68 CPU-seconds over 50 elapsed seconds and peaked at 5,779.23
MiB for the job/container; these are aggregate resources, not per bridge.

Run [36357519258](https://github.com/discourse/discourse/actions/runs/36357519258/job/108728079936)
at head `ff28163e8b3` passed both examples in all four Ruby/Rust/Rust/Ruby
invocations; [Linting passed](https://github.com/discourse/discourse/actions/runs/36357519271/job/108728079778).
The About-page example took 10.61s and 8.10s in Ruby, compared with 3.97s and
3.76s in Rust. The 500-call `Runtime.evaluate` medians were 100.329ms and
106.172ms for Ruby, versus 135.886ms and 162.091ms for Rust. Ruby's medians
averaged 103.251ms, 30.7% below Rust's 148.989ms, so simple CDP round trips do
not explain Rust's faster About-page flow.

The safe parent-driver profile recorded the same locator work in every run:
79 `Driver.find` and 275 `Runtime.callFunctionOn` calls. Ruby's per-method totals
varied substantially between runs (104–396ms for `Driver.find` and 162–645ms
for `Runtime.callFunctionOn`), while Rust stayed near 122–134ms and 159–192ms.
The profile includes system-test setup and teardown. In particular, reset's
`Storage.clearDataForOrigin` call took 3.009s and 3.011s in Ruby, versus 86ms
and 16ms in Rust. `Target.getTargets` took 377–410ms in Ruby and under 1ms in
Rust. Ruby's first `Page.navigate` was a 3.316s outlier; the other three
measurements were 1.446–1.461s. This suggests the gap is concentrated in
browser-level commands and reset/setup behavior rather than locator count.
Core consumed about 47.44 CPU-seconds over 51 elapsed seconds and peaked at
6,021.19 MiB for the whole job/container; these are aggregate resources, not
per-bridge measurements.

Run [36358277219](https://github.com/discourse/discourse/actions/runs/36358277219/job/108730230749)
at head `3a968dbaf7b` passed all four invocations; [Linting passed](https://github.com/discourse/discourse/actions/runs/36358277187/job/108730230586).
The About-page example took 6.48s and 8.23s in Ruby, and 4.17s and 4.09s in
Rust. Three direct `Storage.clearDataForOrigin` samples exposed a large cold
first-call cost in Ruby #1 (3.042s) and both Rust runs (3.022s and 3.019s); the
remaining calls were 9–29ms. Ruby #2's three calls were all 9–14ms. The three
`Target.getTargets` samples were 0.15–0.36ms in every run. These isolated
samples do not show a stable backend-specific penalty for either command; the
first storage-clear delay also occurs with Rust.

The About-page profile still shows intermittent slow browser commands, but the
method changes between Ruby runs: Ruby #1's two `Page.navigate` calls took
3.378s total, while Ruby #2's `Storage.clearDataForOrigin` took 3.013s and
`Target.getTargets` took 377ms. Rust's navigation totals were both about
1.544s, and its corresponding reset commands were fast in this example. Locator
counts remained identical (79 `Driver.find` and 275 `Runtime.callFunctionOn`),
but Ruby's `Runtime.callFunctionOn` total ranged from 172ms to 719ms versus
208–214ms in Rust. Because this profile includes setup and teardown, and the
large Ruby delay moved between navigation and reset, the current runs do not
isolate a repeatable Ruby-versus-Rust cause. Core used about 45.86 CPU-seconds
over 51 elapsed seconds and peaked at 5,900.37 MiB for the entire job; these
resource totals are not per bridge.

The next run starts with the About-page example before the reset-command probe,
but an order audit of run 36358850714 found that RSpec randomized the two
examples: About ran first in both Ruby invocations, while the reset probe ran
first in both Rust invocations. The reset probe's first storage-clear sample
took about 3 seconds in Rust, so it warmed the Rust browser before the About
flow; Ruby paid its cold storage-clear cost inside the About example. This
confounds the apparent About-page comparison and likely explains much of the
measured gap. The next run adds `--order defined` to both bridge commands and
verifies the same example order, with the About-page example first. It retains
profiles split into driver startup, user navigation, reset navigation,
remaining reset work, and the example body, with median and 95th-percentile
latency per CDP method. This will test whether a driver-specific gap remains
after matching browser state and example order.

Run [36359399711](https://github.com/discourse/discourse/actions/runs/36359399711/job/108733428015)
at head `29d98fb8751` passed the two selected examples in each Ruby/Rust/Rust/Ruby
invocation; [Linting passed](https://github.com/discourse/discourse/actions/runs/36359399720/job/108733428110).
RSpec confirmed the About-page flow ran before the reset probe in every
invocation, so the earlier random-order confound is removed. About-page times
were 10.87s, 8.04s, 7.99s, and 8.20s; RSpec totals were 11.14s, 8.28s, 8.23s,
and 8.42s.

The second, later-run Ruby/Rust pair was nearly tied: 8.20s versus 7.99s.
Their `Page.navigate` calls took 1.491s and 1.482s, and the shared reset's
`Storage.clearDataForOrigin` took 3.008s and 3.016s. Ruby's 79 `Driver.find`
calls and 275 `Runtime.callFunctionOn` calls took 108ms and 170ms in total,
slightly less than Rust's 127ms and 184ms. The main measured gap was the
initial `Target.getTargets` command during driver startup: 381ms for Ruby and
174ms for Rust, close to the 210ms difference in total About-page time.

The first Ruby/Rust pair was not stable: Ruby took 10.87s versus Rust's 8.04s.
Ruby's user navigation took 3.358s versus 1.472s, and its locator/call-function
commands had a much longer latency tail; those timings returned to parity in
the second pair. Therefore this run does not support a stable Rust advantage
in the browser interaction path. It points to a small startup-command gap and
large first-run variance. Core used about 46.02 CPU-seconds over 51 elapsed
seconds and peaked at 5,911.20 MiB across the entire job; those aggregate
resources cannot be attributed to one bridge.

The next measurement runs two About-page examples in each RSpec process: the
existing admin-ordering flow first to warm that process's browser and app, then
the expansion flow as the measured target. It profiles both separately. This
keeps the experiment at two examples per bridge and gives the measured flow a
same-process warm-up, while still recording each bridge's initial startup on
the first example.

Run [36360338616](https://github.com/discourse/discourse/actions/runs/36360338616/job/108736130725)
at head `e1278a766ae` passed two examples in each Ruby/Rust/Rust/Ruby invocation;
[Linting passed](https://github.com/discourse/discourse/actions/runs/36360338617/job/108736130706).
The invocation totals were 11.86s, 9.19s, 9.16s, and 9.25s. The CI profile
markers were absent because the profiler was defined inside a spec file that
the narrowed sample no longer loaded. These wall times are not usable for the
driver comparison. The next run explicitly requires the profiler helper before
loading the selected examples.

Run [36360944446](https://github.com/discourse/discourse/actions/runs/36360944446/job/108737886118)
at head `684ec39b146` passed both selected examples in all four Ruby/Rust/Rust/Ruby
invocations and emitted both profiler markers in `warmup` then `measure` order;
[Linting passed](https://github.com/discourse/discourse/actions/runs/36360944453/job/108737885972).
The RSpec totals were 12.04s, 9.21s, 9.12s, and 9.28s; the top-two profile
summaries reported only combined durations of 10.79s, 7.84s, 7.79s, and 7.93s.
Thus the log does not separate the warm-up and measured example wall times.
Core used about 51.66 CPU-seconds over 54 elapsed seconds and peaked at
5,732.32 MiB across the entire job. These aggregate values are not per bridge.

The first About flow paid a cold `Storage.clearDataForOrigin` delay of about
3.01s in every invocation. Its initial `Target.getTargets` call took 388–447ms
in Ruby and 174–186ms in Rust, a repeated 200–270ms startup-path advantage for
Rust. First navigation was a 3.42s Ruby outlier in the first pair, but was
1.49s for Ruby and Rust in the second pair. After the warm-up, the measured
flow's `Page.navigate` took 135–164ms across all four runs. Each bridge made
the same 79 `Driver.find`, 275 `Runtime.callFunctionOn`, and 2 `Driver.click`
calls. The totals for those three operations were about 301ms in both Ruby #1
and Rust #1; in the later pair they were about 253ms in Ruby and 300ms in Rust.
The command profile therefore shows no stable Rust advantage in the warmed
interaction path, while it does show a modest Rust advantage during initial
target discovery. This is not enough by itself to estimate full-suite impact.

Run [36361712191](https://github.com/discourse/discourse/actions/runs/36361712191/job/108740028165)
at head `c6c809d505b` passed both examples in each Ruby/Rust/Rust/Ruby
invocation. The profiler reported the two example durations separately:

| Invocation | Warm-up example | Measured example |
| --- | ---: | ---: |
| Ruby 1 | 9.150s | 1.408s |
| Rust 1 | 6.501s | 1.333s |
| Rust 2 | 6.496s | 1.304s |
| Ruby 2 | 6.726s | 1.259s |

The measured-flow means were 1.334s for Ruby and 1.318s for Rust, only 1.2%
apart; Rust won the first pair by 76ms, while Ruby won the second by 45ms. In
both measured pairs, Ruby spent less time in the 79 `Driver.find`, 275
`Runtime.callFunctionOn`, and 2 `Driver.click` calls combined: 271ms versus
319ms in pair one, and 252ms versus 316ms in pair two. The end-to-end example
time therefore does not show a stable Rust advantage on this warmed flow.

Rust did consistently reach the initial `Target.getTargets` response sooner:
166ms versus 449ms in pair one and 172ms versus 382ms in pair two. Conversely,
the first Ruby warm-up had a 3.434s user navigation versus 1.497s in Rust, but
the later pair was effectively even at 1.483s versus 1.476s. The first
`Storage.clearDataForOrigin` call took about 3.01–3.05s across all four runs;
the backend did not change that cold cleanup cost. This separates a repeatable
roughly 0.2–0.3s startup-query gap from a much larger first-invocation
navigation outlier. The next run reverses the bridge order to test whether
that outlier follows runner position. Core used about 51.66 CPU-seconds over
54 elapsed seconds and peaked at 5,732.32 MiB across the whole job, not per
bridge.

The Core job and both generic checks passed: [Core](https://github.com/discourse/discourse/actions/runs/36361712191/job/108740028165), [check 1](https://github.com/discourse/discourse/actions/runs/36361712256/job/108740028315), and [check 2](https://github.com/discourse/discourse/actions/runs/36361712323/job/108740028172).

The next run reverses the order to Rust/Ruby/Ruby/Rust while keeping the same
two examples, per-example timing, and profiling. This checks whether the
first-invocation navigation outlier follows runner position rather than the
Ruby bridge.
