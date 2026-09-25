# Pitchfork reforking

Pitchfork can promote a warmed request worker into a new mold and gradually
replace the other workers with children of that mold. Those children share
warmed memory through copy-on-write. Reforking is disabled by default.

## Enable reforking

Set this environment variable in the application server's environment and
restart the server:

```text
APP_SERVER_REFORK_AFTER=1000,5000,false
```

Counts apply to individual workers in each generation. In this example,
generation 0 becomes eligible after a worker handles 1,000 requests,
generation 1 after 5,000, and generation 2 stops automatic promotion. Without
`false`, the last count repeats for subsequent generations. Counts must be
positive decimal integers no greater than 2,147,483,647. Whitespace around
entries is allowed; empty entries and a leading or intermediate `false` are
rejected.

This requires Linux and `mini_racer_single_threaded`, which is enabled by
default. A configured schedule with multithreaded V8 fails startup. Removing
the environment variable and restarting disables automatic reforking.

## Fork lifecycle

A request worker can contain state that the initial mold did not:

- Deferred work belongs to its original process. Promotion skips when work
  is queued or executing, and holds the scheduler's admission barrier across
  the fork. A skipped attempt remains eligible after Pitchfork's normal
  retry backoff; it does not consume a generation's schedule entry.
- Rendering and asset compilation share Pitchfork's reentrant fork barrier.
  Promotion skips while another thread holds it instead of waiting for native
  JavaScript execution at the fork boundary.
- A new mold detaches inherited MessageBus client sockets without writing a
  response or shutting down the original worker's connection. Existing
  cleanup timers remove the detached client records. Until cleanup, those
  records can temporarily count toward the long-poll connection limit and
  cause reconnects to use polling.
- Retiring request workers finish their deferred work before exiting and
  refresh their heartbeat while waiting. This also protects a busy worker
  when a different worker promotes. A permanently blocked deferred action
  stalls that retirement; Pitchfork's maximum-unavailable limit bounds the
  number of replacements in progress. Existing deferred-job warnings and
  worker exit/readiness logs expose this condition. Explicit server shutdown
  and process kills retain the existing timeout and non-durable queue semantics.
- Retiring workers complete their remaining long-poll responses before exiting.
  Service descendants restore the base database configuration, so web-only
  database overrides do not propagate into supervised background processes.

The promotion guard applies to both automatic promotion and `USR2` sent to the
Pitchfork monitor. The launcher also handles `USR2`, but uses it for a full
server reload; these are different operations.

The integration with Pitchfork's promotion method and fork lock is covered by
runtime verification and must be rechecked when upgrading Pitchfork. Custom
plugins that start native work in background threads need a fork-safety audit
and must coordinate that work with `Pitchfork.prevent_fork`. Keep reforking
disabled if those integrations are not known to be safe. A single-threaded V8
setting alone does not make arbitrary native libraries fork-safe.

## Measure memory

Measure all Pitchfork processes together: monitor, mold, service process and
request workers, including overlapping generations. RSS counts shared pages
once per process, so its sum is not physical memory consumption. PSS divides
shared pages between the processes mapping them and is the more useful
comparison for copy-on-write savings.

On Linux, sample `Rss` and `Pss` from each process's `/proc/PID/smaps_rollup`.
Keep the code, dataset, worker count, allocator, request mix and successful
request count equivalent between disabled and enabled runs. Record errors,
latency and throughput as well as memory. Compare steady-state samples only
after the expected generation is ready, old processes have exited and the
process count is stable. Also sample generation overlap and available host
memory: a lower steady-state PSS does not rule out a higher transient peak.

Memory savings depend on the workload, worker count and schedule. A result
from a synthetic forum is not a forecast for every production installation.
