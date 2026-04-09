# Sergio Review Feedback (Post "fix request tracking")

## Bugs

- [x] **Fix backfill infinite re-selection for soft-deleted OP** — `app/jobs/scheduled/backfill_nested_reply_stats.rb:18`
  If the OP is soft-deleted, the subquery returns NULL. `s.post_id = NULL` never matches in SQL, so `s.post_id IS NULL` is always true. The topic gets re-selected for backfill every run. Sergio suggests removing `AND p.deleted_at IS NULL` here.

- [x] **Align `deleted_at` filtering between incremental and backfill paths** — `app/models/concerns/has_nested_reply_stats.rb:27`
  The concern filters out soft-deleted ancestors, but the backfill job's raw SQL (lines 38-45, 54-59) doesn't have a `deleted_at` filter. A backfilled topic will have different stats than one built up incrementally. Both paths should be aligned.

- [x] **Filter `deleted_at` in tree_loader children preload** — `lib/nested_replies/tree_loader.rb:113`
  No change needed. Deleted posts are intentionally shown as placeholders for all users (see `PostTreeSerializer#serialize_post` lines 28-47). They hold their place in the tree hierarchy, so preloading them is correct.

## Test Issues

- [x] **Fix ancestor_walker spec testing wrong condition** — `spec/lib/nested_replies/ancestor_walker_spec.rb:87`
  Test passes because `build_chain(2)` sets `reply_to_post_number: nil` for posts[1], so the CTE stops due to the nil check, not because of the `stop_at_op` clause. Needs `reply_to_post_number: 1` to actually exercise the OP boundary.

- [x] **Fix `PUT pin` describe nesting in controller spec** — `spec/requests/nested_topics_controller_spec.rb:422`
  `"PUT pin"` is nested inside the `"GET show"` describe block, but `"PUT toggle"` is at the top level. Likely unintentional.

- [x] **Reference `ROOTS_PER_PAGE` constant instead of hardcoded 20** — `spec/requests/nested_topics_controller_spec.rb:137`
  Hardcodes 20 which depends on `ROOTS_PER_PAGE` being 20. If the constant changes, test silently becomes wrong.

- [ ] **Consider testing public behavior vs private internals in cache test** — `frontend/discourse/tests/unit/services/nested-view-cache-test.js:37`
  Tests access private internals (`_cache`, `_lastNavigationType`, `_popstateTime`) directly. If implementation changes, tests break even if public behavior is the same.

## Consistency / Nits

- [x] **Use `topic.regular?` in initializer** — `config/initializers/300-nested-replies.rb:7`
  Initializer filters out PMs but the backfill job filters to `archetype = 'regular'`. Should use `topic.regular?` for consistency.

- [x] **Preload `nested_topic` for SimilarTopicSerializer** — `app/serializers/topic_list_item_serializer.rb:151`
  `SimilarTopicSerializer` uses `TopicListItemSerializer` which now accesses `nested_topic`. `Topic.similar_to` doesn't preload that association. Low impact since it's a small result set.

## Questions to Answer

- [x] **Clarify silent `limit`/`order` vs warning `method_missing` in post_preloader** — `lib/nested_replies/post_preloader.rb:72`
  Removed `limit`, `order`, and `reorder` — no plugin actually calls these on `topic_view.posts` in their `on_preload` hooks.

## Code Quality

- [x] **Use `#private` class fields instead of `_prefix` convention** — `nested-view-cache.js`, `nested.js`, `nested-context-view.gjs`
  Converted all `_prefix` properties/methods to `#private` where possible. Reserved `_` for `_onMessage` which uses `@bind` decorator. Reworked cache tests to use sinon fake timers and real popstate events instead of accessing private internals.
