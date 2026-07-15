# Hot nested replies performance audit

## Clean rebuild note (2026-07-15)

This file preserves the evidence from audits of `tim/hot-nested-replies` and
`tim/hot-nested-replies-demand-driven`. File paths and implementation details in those historical
sections do not necessarily describe the clean rebuild on `tim/hot-nested-replies-rebuild`.

The rebuild response is documented in `docs/hot-nested-replies-rebuild.md`:

- hot state now uses dedicated snapshot and score tables with bounded retention and backup-data
  exclusion;
- requests are requester-rate-limited and feed a capped, deduplicated, one-hour queue;
- the cluster-serial worker has a cumulative ten-second database budget per minute and applies a
  one-hour cooldown after failure;
- the calculator is one SQL snapshot and propagates public heat through deleted/hidden structural
  placeholders;
- request and worker outcomes expose low-cardinality events, queue depth, and oldest queued age;
- structural backfill finding A remains a separate global nested-replies rollout blocker.

## Scope and conclusion

This audit compares branch `tim/hot-nested-replies` with its `origin/main` merge base and evaluates
the rollout and steady state where nested replies are the default on a site with 5 million topics.

The findings below describe that original branch. The first demand-driven remediation was
implemented on `tim/hot-nested-replies-demand-driven`; the original findings remain here as the
design and rollout risk record.

## Demand-driven implementation re-audit (2026-07-15)

The demand-driven rewrite resolves the original hot-score ship blockers: it removes global hot
invalidation, global hot discovery, per-mutation hot work, continuation draining, and perpetual
reconciliation. Hot sorting is inert behind a default-off gate, cache misses fall back to `top`, the
Redis queue is capped at 1,000 topics, worker starts are bounded to 10 topics/30 seconds per minute,
and each rebuild has a 10-second PostgreSQL statement timeout. The rebuild now calculates and
upserts a coherent snapshot in one SQL statement rather than writing every score twice.

Targeted independent verification on the current worktree ran 182 examples covering the queue,
cache, worker, calculator, nested requests, and structural backfill with 0 failures.

The following issues remain.

### A. Critical: the five-million-topic structural rollout is still unsafe

The rewrite deliberately restores the structural backfill to its merge-base design. With
`nested_replies_default` enabled, that job still considers every regular topic, including topics
with no replies (`app/jobs/scheduled/backfill_nested_reply_stats.rb:21-59`). It writes a zero-count
OP sentinel for each reply-less topic (`app/jobs/scheduled/backfill_nested_reply_stats.rb:114-139`).

At the default batch size of 100 every five minutes, processing 5 million topics takes about 174
days before query and rebuild costs. Once complete, the job still reruns global discovery every
five minutes.

On the local database, the current candidate query took 16.6 ms for only 500 topics, 12,842 posts,
and 11,857 stat rows. PostgreSQL scanned all topics, scanned the stats table twice, and built a
global anti-join over posts and stats before returning 100 candidates (7,871 shared buffers touched).
That plan shape will not scale to a site with millions of topics and many more posts. The
demand-driven hot rewrite is therefore safe to deploy inert, but it does not make enabling nested
replies globally safe.

Category conversion has a related inherited risk: `NestedTopic::ConvertCategory` loops synchronously
until every topic in the category has a `nested_topics` row, in batches of 1,000, before returning
and enqueueing one structural backfill job (`app/services/nested_topic/convert_category.rb:40-92`).
A very large category can therefore hold the initiating request/service worker for an unbounded
number of batches even though each individual insert is bounded.

### B. High: one cheap request can authorize one expensive rebuild

Any caller able to view public nested topics can request `sort=hot` across distinct topics and fill
the shared 1,000-topic queue. The queue bounds memory, but there is no producer rate limit, demand
threshold, per-client budget, or popularity weighting. An enumerating client can starve legitimate
topics and keep the worker near its configured database budget indefinitely.

The worker may start work for 30 seconds per minute, and a final statement can then run for up to
another 10 seconds (`app/jobs/scheduled/recalculate_nested_hot_scores.rb:9-32` and
`lib/nested_replies/hot_score_calculator.rb:16-17,76-94`). That is bounded, but it is still a
meaningful request-to-database amplification path that should be addressed before enabling the hot
gate broadly.

### C. Medium: pathological topics have no failure cooldown

The worker removes a queue item before rebuilding it. A timeout, malformed cycle, or other failure
loses that item, after which the next hot request immediately makes it eligible for enqueue again
(`lib/nested_replies/hot_score_queue.rb:21-29` and
`app/jobs/scheduled/recalculate_nested_hot_scores.rb:37-50`). A frequently requested pathological
topic can repeatedly consume a statement timeout and emit warnings. Add a bounded per-topic failure
cooldown/backoff, while continuing to serve `top` or the stale snapshot.

### D. Medium: demand bounds work rate, not cumulative cache storage

Every successfully rebuilt demanded topic writes a hot row for every post. There is no retention or
eviction policy for snapshots that are never requested again. Organic long-term traffic—or topic
enumeration—can still make `nested_view_post_stats` approach post cardinality over time, just much
more slowly than the original global rollout. Measure demanded-topic coverage and add a cleanup or
sparse-storage plan if it is material.

### E. Medium: rebuilt heat no longer crosses deleted/hidden placeholders

The recursive calculator propagates only through parents that are currently public and then forces
non-public rows' thread score to zero (`lib/nested_replies/hot_score_calculator.rb:208-245`). Existing
nested behavior preserves public descendants beneath deleted regular placeholders, and request
specs expect hot preloading to traverse such placeholders. A freshly rebuilt snapshot can therefore
make a visible descendant branch lose the ancestor heat needed for hot ordering/preloading. Add a
calculator spec for a public descendant under a deleted placeholder and decide explicitly whether
structural regular placeholders may carry public descendant heat.

### F. Medium: observability is not complete enough for rollout

The worker emits one aggregate event after it inspects queue entries, but enqueue results are
ignored. There are no metrics for request mode, queue-full rejection, Redis unavailability, oldest
queue age, timeout topic IDs/cooldowns, or stale-fallback rate. This agrees with the remaining gate
already recorded in `docs/hot-nested-replies-performance-plan.md`; the gate should remain off on
high-traffic sites until those signals and alerts exist.

That original design is not safe for that rollout. Batch sizes bound individual SQL statements, but
they do not bound total queued state, total database work, or sustained worker utilization. The
largest costs also run when the default sort remains `top` and nobody requests `hot`.

## Five-million-topic workload model

| Path | Current behavior | Scale implication |
| --- | --- | --- |
| Enable global default | Visits every regular topic in 1,000-topic pages and inserts every ID into both a structural and hot Redis set | Up to 5,000 invalidation jobs and 10 million Redis set memberships before accounting for drain rate |
| Rebuild drain | Continuously chains more jobs while any Redis set is nonempty | Can consume a Sidekiq worker and database capacity continuously until the global backlog is empty |
| Structural backfill | Up to 2,000 topics per five-minute scheduled cycle | Maximum 576,000 topics/day, or 8.7 days for 5 million topics even if every topic is equally cheap |
| Hot freshness | Rebuilds every active topic every six hours for up to 56 days after its last post | Maximum capacity supports only 144,000 active-window topics before demand exceeds 576,000 rebuilds/day |
| Reconciliation | Rebuilds 100 already-valid topics/hour forever | A 5-million-topic rotation takes about 5.7 years |
| Empty steady-state backfill | Starts again at topic ID zero every five minutes to prove that no stale topic exists | Repeatedly walks the eligible topic population after rollout is complete |

The throughput figures are upper bounds based only on configured batch counts. They ignore topic
size, SQL time, locks, WAL, autovacuum, competing jobs, and request traffic.

## Findings

### 1. Critical: global enablement creates an unbounded Redis and database fan-out

Enabling either the feature or global default advances one global validity cutoff and starts
`InvalidateNestedReplyStats` (`config/initializers/300-nested-replies.rb:9-21`). With the default
enabled, its candidate query includes every regular topic and does not require a reply
(`app/jobs/regular/invalidate_nested_reply_stats.rb:26-43`). Each page puts all IDs into two Redis
sets (`lib/nested_replies/recalculation_queue.rb:84-104`).

For 5 million topics this means up to 5 million structural members plus 5 million hot members.
Redis hash-table encoded sets at this cardinality normally consume hundreds of megabytes; the
actual figure must be measured with production ID widths and Redis configuration. Reply-less topics
are included even though the scheduled backfill and hot candidate queries explicitly exclude them.

The queue drain immediately chains another job while any set remains nonempty
(`app/jobs/scheduled/process_nested_reply_updates.rb:26-29`), so this is not rate limited to the
one-minute schedule. Every reply-less topic still receives a structural read/upsert and a hot marker
upsert.

### 2. Critical: scheduled discovery repeatedly scans global tables

The three discovery jobs derive work by joining `topics`, the OP in `posts`, and
`nested_view_post_stats`. There is no index on either completion timestamp; the stats table only has
a unique `post_id` index.

- Structural backfill runs every five minutes and orders by topic ID
  (`app/jobs/scheduled/backfill_nested_reply_stats.rb:75-113`). Once all markers are current, it must
  walk the eligible topic range to establish that no missing row exists, then repeats from ID zero
  on the next run.
- Hot refresh runs every five minutes and orders by `hot_score_updated_at`, with several `OR`
  freshness predicates (`app/jobs/scheduled/recalculate_nested_hot_scores.rb:44-98`). It cannot use
  the existing `post_id` index to find or order due work.
- Reconciliation runs hourly and orders all valid candidates by `structural_backfilled_at`
  (`app/jobs/scheduled/reconcile_nested_reply_stats.rb:24-53`).

On the local development data, `EXPLAIN (ANALYZE, BUFFERS)` chose a sequential scan of the entire
stats table for both hot discovery and reconciliation. The dataset had only 11,857 stat rows; this
plan shape is unacceptable when the stats table approaches total post cardinality.

Adding timestamp indexes alone would not fully repair this. Topic eligibility and hot due-time are
properties of a topic, but they are stored on a post-stat row and recovered through multiple joins
and `OR` predicates. A topic-level work/state table with indexed `next_refresh_at` and a durable
cursor is a better fit.

### 3. Critical: wall-clock freshness causes massive write amplification

Every topic considered active is fully recalculated every six hours for 56 days
(`lib/nested_replies/hot_score_calculator.rb:8-30` and
`app/jobs/scheduled/recalculate_nested_hot_scores.rb:73-85`), even without mutations.

A full hot rebuild first calculates and upserts every non-OP post, then reads all public posts into
Ruby and persists every score again while propagating thread heat
(`lib/nested_replies/hot_score_calculator.rb:229-430`). Thus a typical post can be rewritten twice
per refresh, about 448 upserts over the 56-day freshness window. These writes also update timestamps,
producing WAL and dead tuples even when ordering changes are immaterial.

At the configured maximum of 2,000 topics per five-minute cycle, the worker can refresh at most
576,000 topics/day. Four refreshes/day means the system falls permanently behind if more than
144,000 topics have activity in the last 56 days, before considering topic size.

### 4. High: the feature shadows much of the `posts` table

Both exact structural recalculation and hot reset create a `nested_view_post_stats` row for every
post in a rebuilt topic, including leaves with zero descendants and non-public/deleted posts
(`lib/nested_replies/structural_stats.rb:96-182` and
`lib/nested_replies/hot_score_calculator.rb:330-373`). Global invalidation also creates an OP stat
for reply-less topics.

With nested replies as the default, the stats table trends toward one row per post, plus its unique
index. Storage, cache pressure, backup size, vacuum work, and migration/index build time therefore
scale with total posts rather than topics that actively use hot sorting.

### 5. High: rollout invalidates useful data globally and duplicates work

The single `nested_replies_stats_valid_after` cutoff makes every earlier structural and hot marker
invalid immediately (`config/initializers/300-nested-replies.rb:14-21`). When enabling the global
default, this also invalidates already-correct explicitly nested topics. Structural counter semantics
have not changed merely because additional topics became eligible.

The Redis invalidation queue, structural backfill poller, and hot poller then independently process
the same invalid markers. A scheduled poller can rebuild a topic before its queued ID is popped, but
the queue worker does not recheck freshness and rebuilds it again. During the backlog, reads see the
global cutoff and fall back to live recursive counts or inline hot calculations, creating a
request-path performance cliff at the same time background load is highest.

### 6. High: hot maintenance is paid even when hot is not the default or used

The shipped default sort remains `top`, but all like, unlike, post creation, recovery, and deletion
events enqueue hot work whenever nested replies are enabled
(`config/initializers/300-nested-replies.rb:35-64`). The five-minute freshness job also has no check
for hot-sort usage. Consequently a site pays global hot storage and maintenance costs simply because
the sort is available in the selector.

### 7. High: generic post updates enter nested-reply callbacks before checking relevant changes

`Post` now has both `after_update` and `after_commit` callbacks. Each callback calls
`nested_replies_tracks_stats?` before determining whether `reply_to_post_number`, visibility, or post
type changed (`app/models/concerns/has_nested_reply_stats.rb:116-123,331-346`). That calls
`topic.nested_view?` for every ordinary post update. Unless associations are already loaded, it can
load both the topic and its `nested_topic` association. This affects unrelated edits such as cooked
or bookkeeping changes across the site whenever nested replies are enabled.

The checks for relevant `saved_change`/`previous_changes` keys should precede topic eligibility.
`Topic#nested_view?` should also test the global default before loading `nested_topic`.

### 8. High: perpetual reconciliation is costly but too slow to provide a useful repair guarantee

The hourly reconciliation intentionally rewrites already-valid topics forever. Each structural
rebuild reads all posts into Ruby and upserts all of their stat rows, updating `updated_at` even when
all values match (`lib/nested_replies/structural_stats.rb:32-45,96-182`). At 100 topics/hour, a
5-million-topic pass takes roughly 2,083 days. It creates continuous scan/write load without a
meaningful maximum time-to-repair.

Reconciliation should target durable dirty/failure signals. If probabilistic corruption detection
is desired, use explicit low-rate sampling with metrics, compare before writing, and avoid global
oldest-marker sorts.

### 9. Medium: mutation work is deduplicated at the wrong granularity

Hot mutations are stored by post ID. A worker groups up to 100 claimed posts by topic, but then
recalculates each changed post path separately under one lock
(`app/jobs/scheduled/process_nested_reply_updates.rb:56-78` and
`lib/nested_replies/hot_score_calculator.rb:169-175`). Busy topics can therefore run many recursive
path queries and overlapping ancestor upserts. Structural and hot topic IDs live in separate random
pop sets, so the same topic's two rebuilds are not reliably co-scheduled.

A topic-keyed dirty record with bit flags and a set of changed branches, plus a threshold that
switches to one full rebuild, would coalesce this work more effectively.

### 10. Medium: stale read fallback duplicates correlated counting work

Hot SQL embeds a correlated direct-reply `COUNT(*)` fallback
(`lib/nested_replies/hot_score_calculator.rb:68-80`). The hot ordering expression includes that
fallback separately for thread score and own score (`lib/nested_replies/sort.rb:13-23`). The recursive
hot preloader repeats the same expressions for candidate rows
(`lib/nested_replies/tree_loader.rb:266-323`). During rollout or queue failure, sorting a wide sibling
set can execute many topic-local correlated counts before applying `LIMIT`.

The request should determine marker validity once, then choose a persisted-score query or a single
pre-aggregated fallback query rather than placing validity and fallback logic in every row's order
expression.

### 11. Medium: large-topic rebuilds have unsafe lock and memory characteristics

Structural rebuilding loads all topic posts into Ruby while holding a PostgreSQL transaction-level
advisory lock. Hot rebuilding loads all public posts into Ruby while holding a distributed mutex
whose validity is fixed at five minutes. Exceptionally large topics can consume substantial worker
memory, hold transactions for a long time, or outlive the mutex validity and overlap another rebuild.
There are no topic-size thresholds, timeouts, lock renewal, or slow-topic quarantine.

### 12. High: there is no operational feedback or load control

The branch has no metrics for candidate-query duration, queue cardinality, oldest backlog age,
topics/posts processed, rows written, lock wait/hold time, fallback-read rate, or reconciliation
drift found. Hidden batch settings change statement size but do not impose a database-time budget or
pause work under load. The removed handoff document itself said lock timing and wide sibling groups
should be instrumented before broad rollout; that instrumentation is not present.

## Recommended smaller architecture

1. Do not globally enqueue topic IDs in Redis. Use a durable database cursor/state row for rollout,
   fetch only topics with replies, and apply a configurable time/load budget per run.
2. Separate structural validity from hot-score validity. Enabling the global default should not
   invalidate already-valid explicit nested topics. Mark each newly processed topic complete rather
   than advancing one global read cutoff first.
3. Remove periodic structural reconciliation from the normal path. Maintain counters incrementally,
   persist dirty topics on mutation/failure, and rebuild only dirty topics. Add low-rate measured
   sampling if corruption detection is required.
4. Make hot maintenance demand driven. Keep mutation-driven engagement data current, but refresh
   time decay only for topics where hot sort was recently requested, or compute topic-local
   freshness during a hot request and cache it in buckets.
5. If exact periodic hot snapshots remain required, create a topic-level state table with
   `topic_id`, version, status, and indexed `next_refresh_at`. Claim bounded work with
   `FOR UPDATE SKIP LOCKED`; do not discover work by scanning post-stat rows.
6. Coalesce mutation work by topic and dirty flags. Recalculate multiple affected paths together,
   switching to one full rebuild beyond a per-topic threshold.
7. Avoid rewriting unchanged rows. Compute structural values, compare them with persisted values,
   and update only differences. Combine hot own-score reset and propagation into one persistence
   pass where practical.
8. Gate hot infrastructure behind an explicit rollout/availability control. Availability of the
   selector should not silently commit every nested-enabled site to global background maintenance.
9. Fix callback guards so unrelated post updates return before loading topic eligibility.
10. Add metrics and rollout guardrails before enabling the feature on a large site, including a
    hard cap on queued/due work and an operator-visible pause mechanism.

## Ship recommendation

Do not ship the current global rollout and periodic refresh design for a site of this scale. The hot
ranking and bounded request preloader can be retained, but the global invalidation queue, polling
discovery, six-hour all-active-topic rewrites, and perpetual structural reconciliation should be
replaced before enabling nested replies by default.
