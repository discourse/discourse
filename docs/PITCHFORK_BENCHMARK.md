# Pitchfork reforking benchmark — 2026-09-25

Across three paired trials at each worker count, reforking reduced steady PSS by a median of 198 MiB (18.4%) with four workers and 375 MiB (24.7%) with eight. Summed RSS did not show a consistent reduction. All 72,000 requests returned successful JSON responses.

Changes below are medians of the three within-pair changes, not differences between independently aggregated medians. Positive RSS changes mean an increase.

| Workers | PSS saved | Summed RSS change | Throughput change | p95 latency change |
| --- | --- | --- | --- | --- |
| 4 | 197.5 MiB (18.4%) | +41.0 MiB (+1.3%) | -0.7% | +2.0% |
| 8 | 375.0 MiB (24.7%) | +32.0 MiB (+0.6%) | +2.6% | -2.4% |

The paired PSS savings ranged from 172.2–212.2 MiB at 4 workers; 326.3–433.7 MiB at 8 workers.

## Transient memory

Reforking temporarily keeps overlapping generations alive. These are the largest sampled process-family totals across the three trials in each mode. Sampling every 250 ms can miss a shorter peak.

| Workers | Mode | Peak summed RSS (MiB) | Peak PSS (MiB) | Lowest host MemAvailable (MiB) |
| --- | --- | --- | --- | --- |
| 4 | baseline | 3064.9 | 1082.6 | 14070.1 |
| 4 | refork | 3564.0 | 1476.6 | 13645.9 |
| 8 | baseline | 5128.1 | 1567.8 | 13509.6 |
| 8 | refork | 5602.1 | 1908.0 | 13098.1 |

Lower steady PSS therefore does not remove the need for refork headroom. PostgreSQL, Redis, Nginx, the load generator and kernel memory are outside the Pitchfork totals.

## Every trial

Each row contains 6,000 successful requests and zero errors. Memory values are MiB. Steady values are medians of 20 samples after the final generation and process IDs remain stable.

| Trial | Steady RSS | Steady PSS | Peak RSS | Peak PSS | Requests/s | p95 ms |
| --- | --- | --- | --- | --- | --- | --- |
| 4w-baseline-20 | 3064.9 | 1082.6 | 3064.9 | 1082.6 | 32.52 | 192.1 |
| 4w-refork-20 | 3059.9 | 870.4 | 3521.0 | 1449.5 | 32.59 | 197.2 |
| 4w-baseline-21 | 3045.2 | 1075.4 | 3045.2 | 1075.5 | 32.71 | 193.5 |
| 4w-refork-21 | 3086.2 | 877.9 | 3564.0 | 1476.6 | 32.39 | 196.1 |
| 4w-baseline-22 | 3024.4 | 1050.3 | 3024.4 | 1050.3 | 32.81 | 193.0 |
| 4w-refork-22 | 3069.0 | 878.1 | 3548.7 | 1384.6 | 32.60 | 196.8 |
| 8w-baseline-20 | 5089.5 | 1510.6 | 5092.4 | 1510.6 | 30.23 | 420.5 |
| 8w-refork-20 | 5121.5 | 1184.3 | 5585.6 | 1848.3 | 29.90 | 425.1 |
| 8w-baseline-21 | 5053.4 | 1517.7 | 5053.4 | 1517.7 | 29.03 | 431.6 |
| 8w-refork-21 | 5138.5 | 1142.6 | 5602.1 | 1908.0 | 29.79 | 421.2 |
| 8w-baseline-22 | 5128.1 | 1567.8 | 5128.1 | 1567.8 | 29.25 | 429.7 |
| 8w-refork-22 | 5106.5 | 1134.2 | 5568.1 | 1796.9 | 30.03 | 417.7 |

## Environment and method

- Dedicated Debian trixie droplet: four virtual CPUs (Intel Xeon Platinum 8358), 16 GiB RAM, Linux 6.12.94. Eight workers exceed the CPU count; this comparison measures memory behavior, not the best worker count for throughput.
- Official Discourse Docker production image, Ruby 3.4.10, Pitchfork 0.18.2, jemalloc, YJIT disabled. Automatic major GC enabled; no out-of-band GC option. Zero Sidekiq workers.
- Discourse base `3dc68f74fc6`, with candidate commit `d968b0f12ae`. The later timeout and GC fixes at `48d46b25510` change paths not exercised by this workload. Confirmation on that published head is recorded separately.
- One synthetic dataset: 100 topics initially containing 10 posts each, plus six posts from correctness checks. No mutations occur during memory trials. Each mode uses the same database and request multiset.
- API-authenticated requests: 50% topic JSON (`/t/:id.json`), 20% latest listings, 10% search for `memory`, 10% categories, 10% topic posts JSON (`/t/:id/posts.json`). Concurrency equals worker count. The isolated admin API rate limit is raised in `discourse.conf` so throttled work cannot count as savings.
- Restart the app server before every trial. Alternate baseline/refork order between pairs. Baseline has `APP_SERVER_REFORK_AFTER` unset; enabled uses `100,500,false`, reaching generation two.
- Sample `Rss` and `Pss` from `/proc/PID/smaps_rollup` for the monitor, mold, service process and every request worker, including overlap. After the workload, require the expected generation, workers plus three total processes, and a stable PID set for 20 samples at 500 ms intervals.
- RSS counts shared pages in each process. PSS divides each shared page among its mappings and is the more useful memory comparison for copy-on-write.

This is a bounded synthetic workload, not a forecast for every production forum. Site size, traffic, plugins, longer-term page dirtying, GC configuration and Sidekiq concurrency can change the result. The tests do not measure Sidekiq throughput. Earlier rate-limited or aborted pilots are excluded.

## Published-fix confirmation

A separate pair at each worker count tested commit `48d46b25510`, including the timeout-recovery and service-GC fixes. All 24,000 requests succeeded and both enabled trials settled at generation two. These results are separate from the three-pair medians above.

| Workers | PSS saved | Summed RSS change | Throughput change | p95 latency change |
| --- | --- | --- | --- | --- |
| 4 | 192.8 MiB (17.9%) | +26.3 MiB | +0.1% | +2.3% |
| 8 | 392.5 MiB (25.3%) | -0.5 MiB | +0.8% | -1.0% |

The largest sampled refork PSS in this confirmation was 1,953.6 MiB with eight workers, versus 1,553.5 MiB in its baseline. The need for transient headroom remains.

