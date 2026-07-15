# Hot nested replies rebuild

## Status

This document is the implementation contract for branch
`tim/hot-nested-replies-rebuild`. The previous prototype is preserved in the named Git stash
`WIP hot nested replies demand-driven prototype before clean rebuild`; its implementation must not
be reapplied wholesale.

Hot sorting is presentation cache data. It is not canonical topic state, and its availability or
freshness must never be required for reading or writing a topic.

### Implementation checkpoint: 2026-07-15

The isolated snapshot and score tables, pure-SQL calculator, bounded Redis queue, requester rate
limit, failure cooldown, retention cleanup, scheduled worker, sort integration, default-off site
setting, and gated selector are implemented on this branch. Structural reply-stat jobs and services
remain unchanged.

Verification completed at this checkpoint:

- 233 backend examples across the complete nested-replies library and request surface, the new
  worker, and root/children/context services pass.
- All 35 nested-view browser examples pass, including the gated hot selector.
- Five rollback-only calculations against the largest local topic (10,008 actual posts) took
  138–180 ms and wrote 10,005 regular/moderator-action carrier rows inside each transaction. A
  follow-up query confirmed that no score or snapshot rows survived the rollbacks.
- On the same topic, an uncached hot root page plus three levels of bounded child preloading loaded
  249 posts in 20 queries and about 36 ms after process warmup. The first measured pass took 84 ms.
- Lint and `git diff --check` pass for the current worktree.

The local machine has PostgreSQL 14 tools, while the repository's canonical structure task is
pinned to PostgreSQL 15–16 and the checked-in structure uses PostgreSQL 15 syntax. The migration was
applied in development and test, and its exact two-table/four-index/version delta is reflected in
`db/structure.sql`; the canonical structure task must still be rerun in a supported environment.

## Safety invariants

1. Deploying the code does no hot-score work. The availability setting defaults to off.
2. Enabling hot sorting does not scan topics, posts, or structural reply statistics.
3. Only a request that selects `hot` on an eligible nested topic may request a calculation.
4. Request threads never calculate or wait for hot scores.
5. A missing, unusable, or failed snapshot falls back to `top`; a stale coherent snapshot remains
   readable while it refreshes.
6. Topics with at most five posts use `top` and never allocate hot cache rows.
7. Topic size is not an eligibility condition. Database time, not post count, bounds a refresh.
8. Refresh work is deduplicated, queue-capacity limited, rate limited by requester, cluster-serial,
   and constrained by a per-minute database-time budget.
9. A failed topic enters cooldown. Repeated requests cannot immediately repeat a pathological
   query.
10. Hot cache storage has its own retention lifecycle and cannot expand structural reply-stat
    coverage.
11. Database backups include the cache schema but exclude cache data.
12. Structural-stat backfills, category conversion, and post mutation paths remain unchanged.

## Ranking contract

Each public regular or moderator-action reply receives an own score from likes, direct public
replies, and time decay. A post's thread score is the maximum of its own score and descendant scores
reduced by a fixed penalty per edge.

Deleted, hidden, and user-deleted regular or moderator-action posts receive no own score, but remain
structural carriers. Heat from a public descendant must cross those placeholders so deleting a
parent cannot make its visible branch disappear from hot ordering. Whispers and other post types do
not contribute or carry public heat.

The calculation is one atomic PostgreSQL snapshot for one topic. It performs no Ruby post
instantiation and has explicit statement and lock timeouts. Cycle detection must fail the snapshot
rather than publish partial results. There is no semantic depth or post-count ceiling.

## Cache ownership

Hot data lives separately from `nested_view_post_stats`:

- One topic snapshot row records calculation time and formula version.
- One score row per cached reply records own and thread scores.
- A refresh updates scores and the topic marker in one transaction, so readers observe either the
  previous complete snapshot or the next complete snapshot.
- Expired topic snapshots and score rows are deleted in bounded batches. Cache deletion is always
  safe because reads fall back to `top`.

No original-post sentinel, global validity timestamp, mutation invalidation, reconciliation, or
topic-discovery query is permitted.

## Request behavior

| State | Effective ordering | Side effect |
| --- | --- | --- |
| Hot setting off | `top` | None |
| Non-hot request | Requested ordering | None |
| Topic is not eligible for nested view | `top` | None |
| At most five posts | `top` | None |
| No snapshot | `top` | Best-effort refresh request |
| Current snapshot within freshness TTL | `hot` | None |
| Current snapshot stale but within retention | stale `hot` | Best-effort refresh request |
| Wrong formula or beyond retention | `top` | Best-effort refresh request |
| Redis unavailable, queue full, or requester limited | Existing fallback | None |

The response continues to identify the user-selected sort as `hot` even when that response used
`top`. Root, context, and children flows resolve the effective sort inside `TreeLoader`.

## Initial resource bounds

Initial values are code constants and should change only after production measurements:

- snapshot freshness: 30 minutes;
- snapshot retention: 30 days;
- refresh queue capacity: 1,000 topics;
- maximum queue residency: one hour;
- requester admission: 20 refresh requests per minute;
- worker: cluster concurrency one, at most ten topics and ten seconds of statement budget per
  minute;
- per-topic failure cooldown: one hour;
- cleanup: bounded score-row and snapshot-row batches.

The worker passes only its remaining time budget to each SQL statement. A slow first topic therefore
cannot authorize another full-timeout query in the same run.

## Observability contract

Refresh processing reports inspected topics, completed topics, posts written, failures, queue
depth, oldest queued age, cooldowns, and duration. Queue admission returns explicit outcomes for
queued, duplicate, requester-limited, cooldown, full, and Redis-unavailable cases. Production
enablement requires dashboards and alerts consuming these low-cardinality outcomes.

## Deliberate exclusions

- No redesign of structural descendant-count backfills in this branch.
- No synchronous score calculation.
- No proactive topic discovery or popularity scan.
- No post, like, edit, delete, or recovery hooks.
- No custom hot-only tree-expansion heuristic in the first version. Existing bounded per-parent
  preloading uses the selected hot order.
- No guarantee that likes or new replies appear in hot order before the cache TTL.

## Rollout

1. Deploy with hot sorting disabled and verify that no queue or cache rows appear.
2. Enable on a development or low-traffic site and verify request modes and SQL timing.
3. Benchmark representative wide and deep large topics with WAL and lock measurements.
4. Canary on a high-traffic site while watching queue age, timeouts, database time, cache growth,
   and stale fallbacks.
5. Keep the setting as an immediate kill switch throughout rollout.
