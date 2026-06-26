# Hot nested replies handoff

Temporary design/handoff note for branch `tim/hot-nested-replies`. Keep this file while the branch is still being tuned and remove before merging to core if we decide the implementation no longer needs a branch-local plan.

## Context

This branch adds a `hot` sort option for nested replies. The goal is broader than a new sort label:

1. Use a useful hot algorithm for nested replies.
2. Smartly pre-open high-quality content on page load.
3. Avoid loading every subtree equally; spend preload work on branches likely to contain hot content.

Important product decision: `hot` is available, but it is **not** the default nested replies sort. The default remains `top`.

## Current branch state

Important changed files on the branch:

- `config/site_settings.yml`
  - Adds `hot` to `nested_replies_default_sort` choices, with default still `top`.
  - Adds hidden tuning settings for hot score propagation, relative scoring, and hot preload budgets.
- `frontend/discourse/app/components/nested/sort-selector.gjs`
  - Adds `Hot` to the UI selector.
- `lib/nested_replies/sort.rb`
  - Adds `hot` to valid algorithms.
  - Orders by `nested_view_post_stats.thread_hot_score DESC`, then `hot_score DESC`, then `posts.post_number ASC`.
- `lib/nested_replies/tree_loader.rb`
  - Applies hot sorting for roots, preloaded children, siblings, and loaded children.
  - Uses smart hot preloading for `sort=hot`.
- `app/services/nested_topic/list_children.rb`
  - Special-cases `sort=hot` for child loading.
- `lib/nested_replies/hot_score_calculator.rb`
  - Calculates own/local `hot_score` using engagement and recency.
  - Calculates propagated `thread_hot_score` and sibling-local relative scores.
- `app/models/concerns/has_nested_reply_stats.rb`
  - Recalculates hot scores when nested reply structure changes.
- `config/initializers/300-nested-replies.rb`
  - Hooks likes, bookmarks, and incoming links to recalculate post hot scores.
- `app/jobs/scheduled/recalculate_nested_hot_scores.rb`
  - Safety-net scheduled recalculation for missing/stale hot score rows.
- `spec/jobs/scheduled/recalculate_nested_hot_scores_spec.rb`
  - Direct coverage for the safety-net job.

Topic-level root replies (`reply_to_post_number IS NULL`) and OP-directed replies (`reply_to_post_number = 1`) are treated as one root sibling group for hot score recalculation, because root loading sorts them as one group.

## Current behavior

Hot sorting works like this:

- Each post keeps an own/local `hot_score`.
- Each post also keeps a propagated `thread_hot_score` using:

```text
thread_hot_score = max(
  own_hot_score,
  child_decay * best_child_thread_hot_score
)
```

- Relative scores are computed per sibling group:
  - `relative_hot_score`
  - `relative_thread_hot_score`
- Roots are sorted by branch `thread_hot_score`, then own `hot_score`, then `post_number`.
- Children under a parent use the same hot ordering.
- For `sort=hot`, descendants preload via a global queue ordered by propagated relative heat with depth decay.
- A total response budget and per-root budget prevent one branch from consuming all preload work.
- Child branches are only queued for deeper preload when they are hot enough relative to the best loaded sibling.

## Hidden tuning settings

Initial defaults:

```yaml
nested_replies_hot_score_child_decay: 0.85
nested_replies_relative_hot_score_min_spread: 1.0
nested_replies_relative_hot_score_floor: 0.0001
nested_replies_hot_preload_post_budget: 60
nested_replies_hot_preload_per_root_budget: 15
nested_replies_hot_preload_children_per_parent: 3
nested_replies_hot_preload_min_relative_score: 0.85
nested_replies_hot_preload_depth_decay: 0.85
```

Use these to tune behavior without code changes. The most likely knobs to adjust first are preload budgets, `nested_replies_hot_preload_min_relative_score`, and the two decay settings.

## Remaining work

- Validate the behavior on real nested topics in the local app.
- Tune hidden settings based on real topic behavior.
- Consider whether the safety-net scheduled job is enough for rollout/backfill, or whether we want an explicit one-time backfill before enabling hot sort broadly.
- Remove this file before merge if the branch no longer needs a handoff/plan.

## Validation already run

```bash
bin/rspec spec/lib/nested_replies/hot_score_calculator_spec.rb \
  spec/lib/nested_replies/sort_spec.rb \
  spec/jobs/scheduled/recalculate_nested_hot_scores_spec.rb \
  spec/requests/nested_topics_controller_spec.rb

bin/lint --fix app/jobs/scheduled/recalculate_nested_hot_scores.rb \
  app/models/nested_view_post_stat.rb \
  config/locales/server.en.yml \
  config/site_settings.yml \
  db/migrate/20260626180655_add_thread_hot_score_to_nested_view_post_stats.rb \
  db/migrate/20260626180703_update_nested_stats_hot_sibling_index.rb \
  db/migrate/20260626191526_add_relative_hot_scores_to_nested_view_post_stats.rb \
  lib/nested_replies/hot_score_calculator.rb \
  lib/nested_replies/sort.rb \
  lib/nested_replies/tree_loader.rb \
  spec/jobs/scheduled/recalculate_nested_hot_scores_spec.rb \
  spec/lib/nested_replies/hot_score_calculator_spec.rb \
  spec/lib/nested_replies/sort_spec.rb \
  spec/requests/nested_topics_controller_spec.rb
```
