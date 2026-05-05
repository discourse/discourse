# Nested Replies: Tracking & Notifications Plan

Working doc for redesigning topic tracking state and notifications for the nested
topic view. Consider this a spec for "tracking light" — the model we believe
actually fits the nested UX, as opposed to porting flat-topic tracking
unchanged.

## The core problem

Topic tracking state does not work for nested view. It was designed for flat
topics where:

- **Tracking** an entire topic gives you an "unread" count on the topic list.
- **Watching** an entire topic gives you notifications for every new reply.

Both assumptions break in nested view:

1. The UI shows "X unread" and number badges, but when you click into the
   topic you can't tell *where* the unread posts live in the tree. The count is
   noise without locality.
2. Notifications for new replies get consolidated. If you create a topic and
   someone leaves a deeply nested reply to another participant, the "new
   reply" notification consolidates with everything else and you can't find
   the conversation that actually concerns you.

The result: counts that don't help you navigate, and notifications that bury
the replies you actually care about.

## What people actually want notifications for

Splitting by role on a nested topic:

### OP (topic author)

- New **root nodes** (single and consolidated). These are top-level
  contributions to their topic.
- Replies to **their own posts** (whether root or nested).
- They do **not** care about replies to other people's roots.
- They do **not** care about deeper nested replies between other participants.

### Replier (someone who joined a thread)

- Replies to **their own posts**.
- They do **not** need a generic "new activity since last visit" signal.
  Direct replies are sufficient.

The pattern: everyone wants direct replies to themselves, and OPs additionally
want a heads-up on new top-level branches in their topic.

## Tracking threads / shadow threads

Decided: **no.**

We could build a "shadow thread" model that tracks per-subtree unread state and
surfaces updates per-thread. It's interesting but overkill for now — the
notification system already covers direct replies, which is what the user
research above says people actually want. Per-thread mute is a likely follow-up
if "tracking light" lands well, but it's out of scope here.

Lean on notifications for direct replies and let the rest go unread without
ceremony.

## Notification levels: keep the semantics, change the defaults

Nested topics are a different animal from flat topics, but that doesn't mean
the notification *vocabulary* needs to change. Watching / Tracking / Regular /
Muted are familiar and already cover the use cases we care about — including
the rare case where a user genuinely wants every reply (they pick Watching,
just like on a flat topic). What changes:

- **Notification levels keep their existing semantics.** Watching = every
  post; Tracking = topic-list signal + direct replies/mentions; Regular = direct
  replies/mentions only; Muted = nothing.
- **Defaults differ based on whether the topic is in nested view.** Nested
  topics push users toward a quieter default than flat topics.
- **No new preferences UI.** The existing per-user notification preferences
  and per-category defaults work as-is. Whether a topic is nested is decided
  at the category (or site) level, not by the user — so we don't need a new
  user-facing toggle.

| Level     | Semantics (unchanged from flat)                                          |
| --------- | ------------------------------------------------------------------------ |
| Watching  | Notification for every new post in the topic.                            |
| Tracking  | Topic-list signal for new activity + notifications for direct replies/mentions. |
| Regular   | Notifications for direct replies/mentions only.                          |
| Muted     | "You will never be notified of anything about this topic, and it will not appear in latest." |

Defaults on a nested topic:

- **OP** → **Tracking** (override of the flat default of Watching). They get
  the topic-list signal for new activity, plus direct-reply notifications.
  Combined with the implementation trick below, this means they're notified
  on every new root and on replies to their own posts — but not on every
  nested reply between third parties.
- **Replier** → **Tracking** (which is already the system default for
  repliers via `UserOption#notification_level_when_replying`). Direct-reply
  notifications fire regardless of Tracking vs. Regular, so the user-visible
  difference is just the topic-list signal — and we're rebuilding that for
  nested anyway. Not worth a special-case downgrade to Regular.
- **OP-on-flat-topic** stays at **Watching** (existing behavior). The change
  here is scoped to nested topics.

Users can override via the same notification-level dropdown we expose on flat
topics; no UI changes to that control.

### Interaction with `notification_level_when_replying`

If a user has explicitly set `UserOption#notification_level_when_replying`, we
respect it — user preference beats nested defaults beats system fallback.
This only matters for repliers; OPs go through `TopicCreator.watch_topic`,
which doesn't consult that preference.

### Interaction with category/tag auto-watch

For an OP creating a new nested topic, **category-watch and tag-watch do
not currently override the Tracking default**. The relevant `auto_watch`
SQL UPDATEs only fire on (1) the topic's tags or category *changing* after
creation or (2) the user's category/tag preference itself changing. Neither
runs at the point a new TopicUser row is created during topic creation, so
the OP keeps whatever level `set_author_notification_level` set (Tracking,
for nested topics).

This wasn't observable in flat mode because the OP defaulted to Watching
anyway — there was nothing for category/tag-watch to upgrade to. Now that
the nested default is Tracking, the gap is visible. Pinned with a test in
`topic_creator_spec.rb` so we don't accidentally change it; if we want to
honor the user's watched-category/tag intent for nested OPs, the fix is an
explicit lookup in `set_author_notification_level` — not in scope here.

## The key implementation trick

The reason Tracking is enough for the OP — even though we want them notified
on every new root — is this:

> **Treat any post with no `reply_to_post_number` as if it were a reply to
> post 1 for notification-generation purposes.**

Once root posts go through the existing "replied" notification path, the OP
receives them at any level ≥ Regular, because direct-reply notifications fire
regardless of Watching/Tracking/Regular. No new notification type, no new
tracking dimension. The OP's Tracking default already covers "every new root"
+ "replies to my posts," which is exactly the OP wishlist from the section
above.

This is the simplification we want to lean on: most of the complexity here
disappears if we route root posts through the existing direct-reply plumbing
and just change defaults.

## What needs to change

Rough scope, expanded based on a code dive. Recommended ship order is roughly
phase 1 → 2 → 3, since each is independently shippable and phase 1 is the
smallest, lowest-risk change.

### Phase 1 — defaults + reply-to-1 redirect (small)

1. **Reply-to-1 redirect for root posts.** Override `Post#reply_notification_target`
   (`app/models/post.rb:521-529`) so that when the topic is nested and
   `reply_to_post_number` is blank, it returns `topic.first_post.user`. This
   reuses the existing direct-reply notification path in `PostAlerter`
   (`app/services/post_alerter.rb:190-203`). Preserve the `user_id <> :user_id`
   filter so the OP doesn't get notified about their own root posts. Do **not**
   modify the database column — only the notification-recipient derivation.
   This keeps serializers, "in reply to" widgets, post-mover, and revision
   history truthful.

2. **Default OP notification level for nested topics → Tracking.** Branch in
   `TopicCreator.watch_topic` (`lib/topic_creator.rb:114-120`) on the nested
   predicate (`topic.nested_topic.present? || SiteSetting.nested_replies_default`,
   already used in `topic_view_serializer.rb:344` and
   `topic_list_item_serializer.rb:152`). Call `topic.notifier.track!` instead
   of `watch_topic!` for nested. Replier defaults are untouched — `PostCreator`
   (`lib/post_creator.rb:675-685`) already defaults repliers to Tracking.

3. **Tests.** System spec covering: OP gets notified on a new root via the
   redirect; OP gets notified on direct replies to their own posts; OP does
   *not* get notified on unrelated deep replies between third parties; user
   pref `notification_level_when_replying` still wins when set; category-watch
   still wins when set.

### Phase 2 — consolidation refactor (the big piece)

This is what actually delivers the "I can find the relevant replies"
promise. Without it, the new defaults still produce a useless inbox on
active topics.

**Shipped (backend):** bucket-scoped reply consolidation.

Reply consolidation is **not** in the pluggable
`Notifications::ConsolidationPlanner` framework — it's hardcoded in
`PostAlerter#create_notification`. We taught that path to bucket by parent
post for nested topics:

1. ✅ **Store `reply_to_post_number` in `notification.data`.** For
   `:replied` notifications we resolve the bucket key (parent post number;
   `1` for nested roots) and persist it in `notification_data` alongside
   `topic_title`/`original_post_id`/etc.

2. ✅ **Scope `destroy_notifications` by bucket.** Added a
   `bucket_post_number:` keyword arg that filters by
   `(data::jsonb ->> 'reply_to_post_number')::int`. For nested + `:replied`,
   we only collapse other `:replied` notifications matching the same
   bucket; we leave `:posted`/`:pm`/`:wcot` and other buckets alone. Flat
   topics are unchanged.

3. ✅ **Bucket-scoped count and "first unread" post.** New
   `unread_posts_in_bucket(user, topic, bucket_post_number)` powers the
   `count` shown in the consolidated `display_username` and the
   `post_number` we point the consolidated notification at. For
   `bucket_post_number = 1` we exclude post 1 itself (it's the root, not a
   reply to it).

**Shipped (frontend):** bucket-aware rendering and click-through.

4. ✅ **Differentiated copy.** New `frontend/discourse/app/lib/notification-types/replied.js`
   handler overrides `label` for consolidated nested notifications:
   - `data.reply_to_post_number == 1` → "N new replies in your topic"
   - `data.reply_to_post_number > 1` → "N new replies to your post"

   New i18n keys live in `config/locales/client.en.yml` under
   `notifications.replied_consolidated_in_topic` and
   `notifications.replied_consolidated_to_post` (pluralized). Singular
   replies (`consolidated_count` absent or 1) keep the existing username
   label. Backend now also persists `consolidated_count` on the notification
   data so the frontend can render counts without parsing the legacy
   `display_username` "X replies" string.

5. ✅ **Click-through to `?sort=new` for the topic bucket.** The Replied
   handler overrides `linkHref` to append `?sort=new` whenever
   `data.reply_to_post_number == 1`, regardless of consolidation. Per-post
   buckets keep the default behavior (jump to the post). Singular topic-bucket
   notifications also get `?sort=new` — the user knows what they're looking
   for is "what's new," and that's what they see.

**Deferred:**

6. **Email + push verification.** Confirm the new bucketing doesn't
   multiply email volume — each bucket could potentially emit its own
   digest item. Worth checking before we ship more broadly.

### Phase 3 — topic-list signal (dot, not count) — shipped

Reuses the existing "new topic" dot UX rather than rendering an unread count.
The count was the original frustration: users see "X unread" but can't find
those posts. The dot is a gentle activity signal that clears on visit.

1. ✅ **Boolean computed without an extra query.** `has_new_replies` on
   `TopicListItemSerializer` returns `bumped_at > user_data.last_visited_at`
   AND `last_post_user_id != current_user.id` AND `last_visited_at` is
   present. Both fields are already on the topic + user_data row, so no
   N+1. The `last_post_user_id` filter prevents the dot from lighting up on
   the user's own contribution; the `last_visited_at` presence check defers
   first-visit handling to the existing `unseen` dot.

   **Deviation from this doc's earlier sketch:** an earlier draft proposed
   `EXISTS (posts.created_at > last_visited_at AND posts.user_id <> current_user.id)`
   — a per-topic posts-table scan. We chose the row-local comparison
   instead to keep the topic list free of any extra query, accepting one
   known false-negative: if user A visits at T1, user B posts at T2, and
   user A then *posts via API without re-visiting* at T3, the dot won't
   light up (because `last_post_user_id == A`). In the typical flow, user A
   navigates to the topic before posting, which calls `track_visit!` and
   updates `last_visited_at`, so the comparison resolves correctly. If this
   edge case ever bites, the upgrade path is the original `EXISTS` shape
   plus a batch preload in `app/models/topic_list.rb`.

2. ✅ **Field gated on nested view.** `include_has_new_replies?` checks
   `Topic#nested_view?` (the predicate added in phase 1) and that the
   request is from a logged-in user. Flat topics don't get the field at
   all.

3. ✅ **Frontend dot.**
   - `frontend/discourse/app/components/topic-list/post-count-or-badges.gjs`
     branches on `@topic.is_nested_view`. Nested topics never render the
     unread-count badge; instead they render the dot when
     `@topic.has_new_replies` is true, otherwise fall back to
     `ItemRepliesCell` (post count).
   - `frontend/discourse/app/components/topic-post-badges.gjs` accepts a
     new `@hasNewReplies` arg; when set, it renders the same shape as the
     existing `new-topic` dot but with class `new-replies` so themes can
     style it independently if desired.
   - New i18n key `topic.has_new_replies` ("new replies since your last
     visit") provides the title/tooltip.

4. ✅ **Visit clears.** Free — `track_visit!`
   (`app/controllers/nested_topics_controller.rb:10`) updates
   `last_visited_at` on every nested-topic show/context request, so the
   boolean flips to false on next render. Entering the topic clears it; no
   need to scroll posts into view.

5. ✅ **Tests.**
   - Serializer spec: 6 cases (true after visit + bump by other; false when
     visited after bump; false when current user was last poster; false
     when never visited; field omitted for flat topics; field omitted for
     anonymous).

### Notification-level UI (no work needed in phase 1)

No semantic changes to the dropdown. Same labels, same meanings. Copy on the
menu items can stay flat-topic-generic. Muted copy is authoritative:
*"You will never be notified of anything about this topic, and it will not
appear in latest."*

## Edge cases on the reply-to-1 redirect

These are small but worth covering in tests so we don't get surprised:

- **OP posts a root themselves.** The existing `reply_notification_target`
  filter `user_id <> :user_id` already prevents self-notification. Preserve
  it in the override.
- **OP's first post is deleted/hidden.** `topic.first_post.user` becomes
  nil → no notification. Probably fine but loud silence if it happens. Worth
  a test asserting the no-recipient case doesn't raise.
- **Whisper / small-action posts.** Already filtered by `notify_about_reply?`
  (`post_alerter.rb:190`). The redirect is downstream of that check, so we
  inherit the filter for free.
- **Topic gets switched from flat to nested mid-life.** The redirect kicks
  in for new posts after the toggle; existing notifications are untouched.
  No backfill problem here.
- **`Watching` users still get every post.** The redirect only affects the
  `replied` notification path. `posted` notifications (which Watching users
  get for every new post regardless of reply structure) are unaffected.
  Watching = "every post" still holds.

## Open questions / deferred

- **Backfill skipped intentionally.** Conversion between flat ↔ nested is
  expected to be rare (it's a category-level decision), so we're not building
  a backfill of per-user notification levels. Existing nested topics will
  carry over whatever levels users already have; new nested topics get the
  new defaults.
- Per-thread mute (mute a subtree, not the whole topic). Out of scope for
  this plan but a likely follow-up if "tracking light" lands well.