# Site Traffic detail benchmark results

## Environment

The measurements ran on 2026-08-06 in one Discourse development environment. The database contained 1,000,000 eligible retained browser pageview events.

This workstation does not represent all production hardware. The results compare bounded workloads in one stable environment.

## Dataset

- The event range covered 30 days.
- The dataset contained 250,000 sessions and four events per session.
- URL frequency was skewed.
- External referrers existed only on entry events.
- Events included country, ASN, browser, and IP dimensions.
- Likely crawler scores applied to 5% of the events.

## Rollup maintenance

`MaintainBrowserPageviewRollups` completed in 1.732 seconds.

| Measure | Result |
| --- | ---: |
| Eligible events | 1,000,000 |
| Country rollups | 84 |
| Referrer rollups | 84 |
| Crawler rollups | 12 |

## Original query at 1,000,000 events

The query timed out under the real 10-second deadline. A diagnostic run with a 60-second deadline completed in 11.323 seconds.

`EXPLAIN (ANALYZE, BUFFERS)` reported these values:

| Measure | Result |
| --- | ---: |
| Execution time | 10,427.843 ms |
| Temporary blocks read | 292,799 |
| Temporary blocks written | 109,908 |

## Window query at 1,000,000 events

The optimized query completed under the real deadline in 8.881 seconds.

`EXPLAIN (ANALYZE, BUFFERS)` reported these values:

| Measure | Result |
| --- | ---: |
| Execution time | 9,327.592 ms |
| Shared blocks hit | 36,240 |
| Shared blocks read | 4,696 |
| Temporary blocks read | 276,632 |
| Temporary blocks written | 79,801 |

Two varied cold requests both completed near 9.2 seconds.

Two identical `CachedQuery` requests caused one computation. Both requests returned near 9.05 seconds.

Four varied cold requests all timed out near 10.10 seconds. This run shows a concurrency limit on this workstation at the one-million-event cap.

## Window query at 750,000 events

Four varied cold requests all completed. Their times ranged from 8.735 seconds to 8.945 seconds.

## Checked-in runner verification

The checked-in runner completed on 2026-08-06 local time.

| Measure | Result |
| --- | ---: |
| Configured cap | 750,000 |
| Retained events | 1,000,000 |
| Eligible events | 1,000,000 |
| Eligible sessions | 250,000 |
| Cold unfiltered request | Success in 8.678 s; 750,000 events analyzed |
| Two identical `CachedQuery` requests | One computation; 6.988 s and 7.077 s |
| Four varied typed cold requests | All succeeded; 7.186–7.313 s |

## Decision

Keep the one-million-event development population for performance tests. Ship 750,000 as the default and hard maximum.

The response continues to disclose the requested range, analyzed range, event count, cap, and excluded earlier events.
