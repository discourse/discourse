# Nested Replies: Core Migration Status

Tracking document for the migration of `discourse-nested-replies` from plugin to core.

---

## Completed

### File moves and namespace changes

All plugin files have been moved to core locations with the namespace changed from
`DiscourseNestedReplies` to `NestedReplies`.

| What | Core location |
|---|---|
| Module + constants | `lib/nested_replies.rb` |
| TreeLoader | `lib/nested_replies/tree_loader.rb` |
| AncestorWalker | `lib/nested_replies/ancestor_walker.rb` |
| PostPreloader | `lib/nested_replies/post_preloader.rb` |
| PostTreeSerializer | `lib/nested_replies/post_tree_serializer.rb` |
| Sort | `lib/nested_replies/sort.rb` |
| Controller | `app/controllers/nested_topics_controller.rb` |
| Model | `app/models/nested_view_post_stat.rb` |
| Setup (callbacks, serializers, custom fields, events) | `config/initializers/300-nested-replies.rb` |
| Migration (idempotent) | `db/migrate/20260325120000_create_nested_view_post_stats_in_core.rb` |
| Settings | `config/site_settings.yml` (under `posting`) |
| Server locale | `config/locales/server.en.yml` |
| Client locale | `config/locales/client.en.yml` (under `nested_replies`) |
| Routes | `config/routes.rb` |
| SVG icons | `vendor/assets/svg-icons/nested-replies-icons.svg` + `SVG_ICONS` in `svg_sprite.rb` |
| SCSS | `app/assets/stylesheets/common/nested-view.scss` (imported in `common.scss`) |
| 9 components | `frontend/discourse/app/components/nested-*.gjs` |
| Route + controller + template | `frontend/discourse/app/{routes,controllers,templates}/nested.*` |
| 2 libs | `frontend/discourse/app/lib/{nested-post-url,process-node}.js` |
| Service | `frontend/discourse/app/services/nested-view-cache.js` |
| 3 instance-initializers | `frontend/discourse/app/instance-initializers/nested-*.js` |
| 3 connectors | `frontend/discourse/app/connectors/{topic-navigation,category-custom-settings}/` |
| Route map entry | `frontend/discourse/app/routes/app-route-map.js` |
| System specs (11) | `spec/system/nested_*.rb` |
| Page object | `spec/system/page_objects/pages/nested_view.rb` |
| Request spec | `spec/requests/nested_topics_controller_spec.rb` |
| Lib specs | `spec/lib/nested_replies/` |
| Serializer spec | `spec/serializers/nested_replies_basic_category_serializer_spec.rb` |
| Support helper | `spec/support/nested_replies_helpers.rb` |
| JS tests (3) | `frontend/discourse/tests/unit/{lib,controllers}/` |

### Core file modifications

| File | Change |
|---|---|
| `app/models/topic.rb` | `has_one :nested_topic`; removed custom field from `editable_custom_fields` |
| `app/models/category.rb` | Delegated `nested_replies_default` to `category_setting` |
| `app/models/post.rb` | `include HasNestedReplyStats` concern |
| `app/controllers/topics_controller.rb` | Added `post_number` to redirect query param allowlist (was a plugin modifier) |
| `app/controllers/categories_controller.rb` | Added `nested_replies_default` to `category_setting_attributes` permit list |
| `app/serializers/post_serializer.rb` | Added `direct_reply_count` attribute (gated on `@topic_view`) |
| `app/serializers/topic_list_item_serializer.rb` | Added `is_nested_view` attribute (via `nested_topic` association) |
| `app/serializers/topic_view_serializer.rb` | Added `is_nested_view` attribute (via `nested_topic` association) |
| `app/serializers/category_serializer.rb` | Added `nested_replies_default` to `CategorySettingSerializer` |
| `lib/topic_view.rb` | Added `nested_replies_direct_reply_counts` accessor + memoization; `:nested_topic` in `find_topic` includes; `preloaded_post_data` / `set_preloaded_post_data` API for plugins to store per-post data that survives `@posts` replacement |
| `lib/topic_query.rb` | Added `:nested_topic` to default topic includes |
| `lib/svg_sprite.rb` | Added `nested-circle-minus`, `nested-circle-plus`, `nested-thread` to `SVG_ICONS` |
| `frontend/.../components/topic-admin-menu.gjs` | Added nested replies toggle button directly |
| `frontend/.../components/post/menu.gjs` | Added `NestedRepliesExpandButton` to core button map |
| `frontend/.../components/admin-post-menu.gjs` | Added nested pin/unpin button directly |
| `frontend/.../components/post/menu/buttons/replies.gjs` | Hidden on nested route via `shouldRender` |

### What was kept from the plugin-era Core commits

These were added to core in `c839e1121ec` and `b3bbef2e577` to support the plugin:

- ~~**3 value transformers** — removed; URL logic now in `Topic#url`, `Post#url`, server redirect~~
- **`TopicCategoryTagEditor` component** extracted from `topic.gjs`
- **`PostDependentCache` concern** and `reset_post_collection` / `skip_post_loading` in `TopicView`
- ~~**`topic-post-stream` PluginOutlet** — already removed~~
- ~~**`topic-navigation.gjs` changes** — already removed~~

---

## TODO: Clean up for a proper core implementation

Items roughly ordered by priority/risk. Check off as completed.

### High priority

- [x] **Initializer callback duplication on reload**: Moved Post callbacks into a proper
  concern (`app/models/concerns/has_nested_reply_stats.rb`) included in `Post`.

- [x] **Decompose the initializer entirely**: The monolithic initializer has been broken up:
  - **Post callbacks** -> `app/models/concerns/has_nested_reply_stats.rb` concern
  - **TopicView accessors + on_preload** -> `attr_accessor` and `memoize_for_posts` inlined
    directly in `lib/topic_view.rb`; preload hooks in `lib/nested_replies/topic_view_preload.rb`
  - **Serializer attributes** -> inlined directly in `post_serializer.rb`,
    `topic_list_item_serializer.rb`, `topic_view_serializer.rb`, and `category_serializer.rb`
  - **DiscourseEvent handler** -> slim initializer `config/initializers/300-nested-replies.rb`

- [x] **Custom fields -> real schema**: Replaced all 3 custom fields with proper models/columns:
  - `nested_replies_default_for_category` -> `category_settings.nested_replies_default` column
    (delegated from `Category`, serialized via `CategorySettingSerializer`, saved via
    `accepts_nested_attributes_for`)
  - `nested_replies_pinned_post_number` + `nested` -> new `nested_topics` table/model
    (`NestedTopic`). Row existence = topic has nested view enabled. `pinned_post_number`
    column on the same table. `Topic` has `has_one :nested_topic, dependent: :destroy`.
  - All custom field registrations, preloading, and references removed
  - `TopicQuery` and `TopicView#find_topic` include `:nested_topic` to prevent N+1

### Medium priority

- [x] **Remove `topic-post-stream` PluginOutlet** from `topic.gjs`: Already removed.
  `<PostStream>` renders directly without the outlet wrapper.

- [x] **Remove `topic-navigation.gjs` changes**: Already removed. Neither `hideTimeline`
  nor `topic:view-mode-changed` exist in the current file. No plugins depend on either.

- [x] **discourse-reactions coupling**: Removed all reactions-specific code from nested
  replies. discourse-reactions now owns its own preloading via a `TopicView.on_preload`
  hook that batch-preloads associations, counts, and precomputed reactions for all posts.
  The nested view's `PostPreloader#prepare` calls `TopicView.preload(topic_view)` which
  triggers this hook generically — no plugin-specific knowledge needed.

  **New core API — `TopicView#preloaded_post_data`**: Some `on_preload` hooks replace
  `@posts` entirely (e.g., discourse-global-communities), creating fresh Post objects and
  losing per-post data set by other hooks. To solve this, added a generic key-value store
  on TopicView for plugins to stash per-post preloaded data (keyed by post_id):
  - `topic_view.set_preloaded_post_data(namespace, data)` — store a hash
  - `topic_view.preloaded_post_data(namespace)` — retrieve it
  - Auto-clears on `reset_post_collection` via `memoize_for_posts`
  - discourse-reactions uses `:reactions` and `:reaction_users_count` namespaces
  - Serializer attributes look up from the map, falling back to per-post queries

  Deleted from core:
  - `NestedReplies.batch_precompute_reactions` (~76 lines of SQL)
  - `lib/nested_replies/post_serializer_reactions_patch.rb` (global `PostSerializer` prepend)
  - `PostPreloader#preload_plugin_associations` (hardcoded reactions preloading)
  - Second `on_preload` hook in `topic_view_preload.rb`
  - `attr_accessor :precomputed_reactions` from `HasNestedReplyStats` (moved to reactions'
    `PostExtension`)

  Also fixed a latent bug in the batch SQL: used `dr.post_id` (reactions table) instead of
  `dru.post_id` (reaction_users table) which wasn't reliably populated.

- [x] **Convert instance-initializers to native core patterns**:
  - **Topic admin button** -> added directly to `topic-admin-menu.gjs`
  - **Post menu button** -> `NestedRepliesExpandButton` added to core button map in
    `post/menu.gjs`; "replies" button hidden on nested route via `shouldRender` check;
    admin pin button added directly to `admin-post-menu.gjs`
  - **View redirect** -> removed entirely (see below)

- [x] **Remove URL transformers and client-side redirect hijacking**: All three value
  transformers (`route-to-url`, `topic-url-for-post-number`, `post-share-url`) and the
  `nested-view-redirect.js` instance-initializer have been removed. Replaced with:
  - **Server-side redirect**: `TopicsController#show` redirects HTML requests to `/n/`
    when topic has nested view enabled
  - **Client-side redirect**: `topic/from-params.js` `afterModel` checks `is_nested_view`
    and replaces with the nested route for in-app navigation
  - **Model URLs**: `Topic#url` returns `/n/slug/id` when `is_nested_view`;
    `Post#url` returns `/n/slug/id/N` for nested topics
  - **URL format**: Changed from `/nested/slug/id?post_number=N` to `/n/slug/id/N`
  - **Ember routes**: `nested` at `/n/:slug/:topic_id` + `nestedPost` at
    `/n/:slug/:topic_id/:post_number`
  - **Removed**: `/nested/check/:id` endpoint, `route-to-url` transformer from `url.js`,
    all three transformer registrations from `transformers.js`

- [x] **Topic list item URLs include post number for nested topics**: For nested topics,
  `lastUnreadUrl`, `lastReadUrl`, and `lastPostUrl` on the Topic model were appending
  post numbers to the URL (e.g., `/n/slug/id/5`), which navigates to a subthread view
  instead of resuming reading position. Fixed by returning just `this.url` (no post
  number) when `is_nested_view` is true. `urlForPostNumber()` is unchanged so intentional
  post linking (search results, share URLs) still works.

- [x] **Fix `TopicView#topic_user` and `#read_posts_set` N+1**: Ruby's `||=` doesn't
  cache `nil` results, and `return` inside `||= begin...end` bypasses the assignment
  entirely. This caused 278 repeated `topic_users` queries per request (one per post)
  when the user had no `TopicUser` record. Fixed by switching to
  `instance_variable_defined?` for nil-safe caching. This is a core `TopicView` bug
  that also affects the normal topic view for first-time visitors. Reduced total queries
  on nested roots endpoint from ~424 to ~96.

### Low priority

- [x] **`PostsArray` shim in PostPreloader**: Added `method_missing` + `respond_to_missing?`
  fallback so that any AR method not explicitly shimmed falls back to a real
  `Post.where(id: ...)` relation instead of crashing. Common methods (`includes`, `pluck`,
  `where`) still use efficient in-memory implementations to avoid re-querying.

- [x] **`nested_post` parameter in post adapter**: Unrelated to nested replies — it's a
  2015-era backwards-compatibility flag that opts the Ember client into the full JSON
  envelope (`{post, action, success}`) vs the bare post object. The composer service
  depends on `responseJson.action`, `.post`, `.route_to`, etc. Added a clarifying comment.

- [x] **Test coverage gaps**: Added QUnit tests for nested-view-cache service,
  process-node lib, nested controller state/message-bus logic, and
  process-node lib. Added system specs for post editing/saving,
  deletion (user + admin, preserving children), pagination (roots + children),
  and real-time MessageBus updates (`nested_post_lifecycle_spec.rb`,
  `nested_pagination_spec.rb`, `nested_realtime_spec.rb`).
  Mobile/responsive — not yet covered (CSS-only, low priority).

- [x] **Remove `PostScreenTracker` — use core's `ScreenTrack` service**: Added
  `observePost(element, post)` and `unobservePost(element)` to the core
  `ScreenTrack` service with a lazily-created `IntersectionObserver`. Deleted the
  standalone `PostScreenTracker` class and removed the `@postScreenTracker` prop
  threading from 8 component/template files. `NestedPost` and `NestedOp` now
  inject `@service screenTrack` directly.

---

## Tests

All currently passing:

| Suite | Count | Status |
|---|---|---|
| `spec/lib/nested_replies/` | 33 | passing |
| `spec/requests/nested_topics_controller_spec.rb` | 61 | passing |
| `spec/serializers/nested_replies_basic_category_serializer_spec.rb` | 2 | passing |
| `plugins/discourse-reactions/spec/` (non-system) | 160 | passing |
| JS unit tests (6 files) | 67 | passing |
| System specs (14 files) | not yet run (need server) | — |
