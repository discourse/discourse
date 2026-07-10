# Hot nested replies

This branch adds a `hot` sort for nested topics and a bounded preloading strategy that opens the branches most likely to contain recent, engaging replies.

`hot` is available to users and can be selected as `nested_replies_default_sort`, but the shipped default remains `top`.

## Ranking model

Every non-OP post has two persisted values in `nested_view_post_stats`:

- `hot_score`: the post's own recency and engagement.
- `thread_hot_score`: the best score reachable through that post's visible branch.

The own score is:

```text
engagement = like_score + 2 * public_direct_reply_count
hot_score = ln(1 + engagement) + created_at_epoch / time_scale
```

The fixed time scale is 48 hours. This means one ordinary like offsets about 33 hours of age, one direct reply offsets about 53 hours, and 100 likes offset about nine days. The logarithm gives early engagement meaningful weight without letting large counts grow linearly forever. This is deliberately slower and more engagement-heavy than [Reddit's archived link-ranking formula](https://github.com/reddit-archive/reddit/blob/master/r2/r2/lib/db/_sorts.pyx) because forum topics live longer; it still needs validation against real topic distributions. Direct replies can also reflect controversy or reply farming, so their weight is a product choice rather than a neutral quality signal.

Thread heat propagates upward with an additive nesting penalty:

```text
thread_hot_score = max(
  hot_score,
  best_public_child_thread_hot_score - child_penalty
)
```

The fixed child penalty is `0.25`, equivalent to 12 hours at the 48-hour time scale.

Two properties are intentional:

1. The time scale is fixed across an entire tree. Scores from different levels are therefore comparable.
2. The nesting penalty is additive. Changing the timestamp epoch adds the same constant to every branch and cannot change the ranking.

These properties are required for descendant activity to bubble into ancestor ordering predictably. A multiplicative penalty must not be applied to a score containing an absolute timestamp.

## Ranking signals and visibility

The score deliberately uses only likes and public direct replies.

- Reads are excluded because they mostly measure prior exposure and would create a self-reinforcing visibility loop.
- Bookmarks are excluded because the legacy post counter is incomplete and bookmarks are private.
- Incoming links are excluded because repeated referrers are a weak, gameable engagement signal.

Only regular and moderator-action posts form score propagation paths. Whispers and small actions cannot change public ordering or consume the public preload budget. Deleted, hidden, and user-deleted posts have no own heat, although a regular-post placeholder can still carry heat from public descendants that remain reachable beneath it. Preserving those structural placeholders is intentional: removing the node would orphan otherwise visible replies below it. Deleted nodes use the nested view's minimal placeholder, while hidden nodes retain the core cooked-hidden representation.

The score is intentionally global rather than viewer-specific. Storing a public-only score keeps ordering consistent and avoids leaking staff-only activity through rank changes.

## Pre-expansion

Hot preloading first materializes a bounded candidate tree: at most the top configured children per parent and at most the normal preload depth. It then spends the response budget with a deterministic best-first queue.

```text
preload_priority = thread_hot_score - depth * preload_depth_penalty
```

The queue uses:

- a total response budget;
- a per-starting-root budget so one branch cannot monopolize the response;
- a per-parent child limit;
- post number as the final deterministic tie-breaker.

Candidate discovery is batched into one recursive query and selected posts are loaded together. It does not issue a score query and association preload for every expanded parent. The response budget bounds serialized posts, not the recursive query itself: candidate work is bounded separately by a hard depth of three and at most five children per parent. With the defaults, a 50-post child page can materialize up to 1,950 candidates; the configured maximum is 7,750. Very wide sibling groups should be benchmarked because each parent still sorts its direct children before applying the per-parent limit.

Initial tuning values:

```yaml
nested_replies_hot_preload_post_budget: 60
nested_replies_hot_preload_per_root_budget: 15
nested_replies_hot_preload_children_per_parent: 3
nested_replies_hot_preload_depth_penalty: 0.25
```

The preload values are hidden site settings so real-topic evaluation can tune response selection without rewriting persisted scores. The 48-hour score scale and `0.25` propagation penalty are code constants. They must not become live settings without a formula version and coordinated full rebuild; mixing persisted scores from different time scales makes old and new rows incomparable.

## Freshness and rollout

Production post creation is recalculated from the `post_created` event, after `PostCreator` has saved reply relationships. Likes, unlikes, post deletion, recovery, reparenting, hiding/unhiding, and public post-type transitions refresh the changed path. A path refresh reads the changed post and all ancestors in one query and persists their scores in one bulk upsert, so query count does not grow with nesting depth. Mutations run after the surrounding database transaction commits and are serialized by topic, so concurrent sibling updates cannot overwrite an ancestor with a stale maximum or deadlock across database and distributed locks. Full-topic reset, propagation, and marker updates are one database transaction, preventing readers from seeing a half-propagated rebuild.

The scheduled job serves two purposes:

- backfill missing scores in batches after rollout or after nesting is enabled;
- refresh the oldest scores after seven days as a safety net for missed events or a coordinated formula update.

It orders by the oldest score timestamp, preventing newer topics from permanently starving older topics. It also includes existing topics covered only by the site-wide nested-view default. Explicitly enabling nesting enqueues an immediate topic refresh.

Topic refresh age is stored on the OP's existing stats row. Structural backfill completion has its own `structural_backfilled_at` marker; OP row existence is not treated as completion because a live reply can create a partial counter row. The hot-score job waits for that structural marker and only updates its hot-refresh timestamp. The structural backfill also covers site-wide-default nested topics. This ownership prevents hot rollout from skipping or starving direct and descendant counter backfills.

Missing score rows fall back to an own recency score during reads, so an unbackfilled new reply does not sort below every persisted historical reply.

### Development database compatibility

The final implementation consolidates its schema into migration `20260609150000` and removes three draft migrations that existed only on the feature branch: `20260626180655`, `20260626180703`, and `20260626191526`. A development or test database that ran those draft migrations must be recreated before testing this version; Rails cannot automatically reconcile an already-recorded, rewritten migration. Fresh databases and sites that never ran the feature branch are unaffected.

## Known product behavior

- Hot order is a snapshot for the current request. Existing nested-view live updates do not jump posts around while someone is reading.
- Offset pagination can duplicate or skip items if engagement changes between pages, as with other mutable offset-sorted lists. Cursor or snapshot pagination would be a separate product change.
- Smart pre-expansion runs when the selected sort is `hot`; `top`, `new`, and `old` retain their existing breadth-first preload behavior.
- Missing-score fallback does not reconstruct descendant heat or visible direct-reply engagement. Explicitly enabling nesting queues a full topic refresh, so the first request can temporarily use recency-and-likes-only order.
- Hot mutations serialize on a per-topic distributed lock. This closes a lost-update race, but unusually busy topics or a slow full refresh can add request latency; lock wait and hold time should be instrumented before broad rollout.
