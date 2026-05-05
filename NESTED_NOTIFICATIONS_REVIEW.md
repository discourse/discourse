# Nested Notifications & Tracking — Pre-Review Self-Audit

Issues found in the implementation on `nested/notifications-and-tracking`,
ordered by severity. Companion to `NESTED_NOTIFICATIONS_AND_TRACKING.md`
(the spec) and the actual code on this branch.

Each issue includes: where it is, why it's wrong, the proposed fix, and how
to verify. The 🔴 items are real bugs; 🟡 are quality concerns worth
addressing; 🟢 are reviewer-readiness nits.

---

## 🔴 1. Flat-topic consolidated `:replied` notifications get the new "X new replies to your post" copy

**Location:** `app/services/post_alerter.rb` — the block right after
`notification_data = { ... }`:

```ruby
if type == Notification.types[:replied]
  notification_data[:reply_to_post_number] = bucket_post_number ||
    original_post.reply_to_post_number
  notification_data[:consolidated_count] = consolidated_count if consolidated_count
end
```

**Why it's wrong:** The frontend `Replied` handler
(`frontend/discourse/app/lib/notification-types/replied.js`) keys the new
copy on `data.reply_to_post_number != null`:

```js
get isBucketed() {
  return this.notification.data.reply_to_post_number != null;
}
get label() {
  if (this.consolidatedCount > 1 && this.isBucketed) {
    const key = this.isTopicBucket
      ? "notifications.replied_consolidated_in_topic"
      : "notifications.replied_consolidated_to_post";
    return i18n(key, { count: this.consolidatedCount });
  }
  return super.label;
}
```

For a **flat topic** where the user replied to a specific post (say post 5),
the alerter currently stores `reply_to_post_number: 5` and
`consolidated_count: N`. The frontend then renders "**N new replies to your
post**" — replacing the legacy "X replies" copy that flat topics used to
get. That's an unintended behavior change. The spec explicitly says flat
topics are unchanged.

The same issue applies to `linkHref`: a flat-topic notification with
`reply_to_post_number == 1` would get `?sort=new` appended, which is wrong
for flat topics (they don't have a nested-view sort).

**Fix:** only persist the bucket fields when bucketing was actually applied
(i.e., for nested topics where `bucket_post_number` was set):

```ruby
if bucket_post_number
  notification_data[:reply_to_post_number] = bucket_post_number
  notification_data[:consolidated_count] = consolidated_count if consolidated_count
end
```

**Verify:**
- Add a regression spec in `spec/services/post_alerter_spec.rb`: a flat
  topic where two users reply to post 5; assert the consolidated
  notification's `data_hash` does **not** contain `reply_to_post_number` or
  `consolidated_count`.
- Run `bin/rspec spec/services/post_alerter_spec.rb` — all existing nested
  tests must still pass.
- Run `bin/qunit frontend/discourse/tests/unit/lib/notification-types/replied-test.js`
  — the existing "label falls back to display_username for flat topics
  (no bucket)" test should already cover this from the frontend side.

---

## 🟡 2. `Post#reply_notification_target` may trigger lazy association loads

**Location:** `app/models/post.rb`:

```ruby
def reply_notification_target
  target_post_number = reply_to_post_number
  target_post_number = 1 if target_post_number.blank? && topic&.nested_view?
  ...
end
```

**Why it matters:** `topic&.nested_view?` reads two associations:
`post.topic` and `topic.nested_topic`. In the main `:replied` path
(`PostAlerter#after_save_post`) the post is in scope, but `nested_topic`
isn't preloaded. Per call we hit one extra query for `nested_topic`. For
single-post creation it's fine; for bulk operations (post import, mover,
etc.) it could add up.

**Fix:** Two options. Lower-effort: leave as-is and call out in PR
description so reviewer can suggest preloads at hot call sites. Better:
add a `preload(:nested_topic)` in places that batch-process posts (search
the codebase for `reply_notification_target` callers).

**Verify:** Audit callers via
`grep -rn "reply_notification_target" --include="*.rb"` and add preloads
where lists are processed.

---

## 🟡 3. `unread_posts_in_bucket` deviates from `unread_posts` semantics

**Location:** `app/services/post_alerter.rb`:

```ruby
def unread_posts_in_bucket(user, topic, bucket_post_number)
  last_read =
    TopicUser.where(user_id: user.id, topic_id: topic.id).pick(:last_read_post_number) || 0

  scope =
    Post.secured(Guardian.new(user)).where(topic_id: topic.id).where("post_number > ?", last_read)

  if bucket_post_number == 1
    scope.where("reply_to_post_number IS NULL OR reply_to_post_number = 1")
         .where("post_number > 1")
  else
    scope.where(reply_to_post_number: bucket_post_number)
  end
end
```

**Why it matters:** The original `unread_posts` filters to posts the user
"cares about" (reply_to_user_id matches, or user is watching the
topic/category/tag). The bucket version doesn't — it counts any unread
post in the bucket. This is a deliberate design choice (the bucket *is*
the scope) but it's a real deviation from the existing flat-topic
semantics.

For a nested-OP at Tracking, the bucket-1 scope returns "all unread root
posts." That's exactly what we want for the consolidated notification
count. But it's worth flagging because a reviewer comparing the two
helpers will notice.

**Fix:** Document the choice with a code comment and call it out in the
PR description. No code change needed.

---

## 🟡 4. Transition behavior for pre-deploy notifications

**Location:** `app/services/post_alerter.rb` —
`destroy_notifications(..., bucket_post_number:)`:

```ruby
scope = scope.where(
  "(data::jsonb ->> 'reply_to_post_number')::int = ?",
  bucket_post_number,
)
```

**Why it matters:** Pre-deploy `:replied` notifications don't have
`reply_to_post_number` in `data`. Post-deploy:

- The bucket-scoped destroy predicate yields NULL for legacy rows → they
  are **not** matched → never wiped by the new flow.
- New bucketed notifications coexist with legacy bulk-consolidated ones
  until `Notification.purge_old!` ages them out or the user reads/dismisses
  them.
- Not data-corrupting, but a few users may see one "legacy lump"
  notification plus per-bucket ones for a brief window.

**Fix:** Acceptable as-is. Either (a) explicitly mention the transition in
release notes, or (b) on first nested-bucket destroy in a topic, also wipe
any `:replied` notifications **without** `reply_to_post_number` for that
topic, treating them as legacy. Suggested predicate:

```ruby
scope = scope.where(
  "(data::jsonb ->> 'reply_to_post_number')::int = ? OR (data::jsonb ->> 'reply_to_post_number') IS NULL",
  bucket_post_number,
)
```

(Only do this if the messy-transition concern is voiced in review.)

**Verify:** If applied, add a spec in `post_alerter_spec.rb` simulating a
legacy notification (one without `reply_to_post_number` in `data`) and
asserting the next bucket-scoped destroy wipes it.

---

## 🟡 5. `existing_notification_of_same_type` predates the bucket logic

**Location:** `app/services/post_alerter.rb` —
`create_notification`:

```ruby
existing_notifications =
  user
    .notifications
    .order("notifications.id DESC")
    .where(topic_id: post.topic_id, post_number: post.post_number)
    .limit(10)

existing_notification_of_same_type =
  existing_notifications.find { |n| n.notification_type == type }

if existing_notification_of_same_type &&
     !should_notify_previous?(user, post, existing_notification_of_same_type, opts)
  return
end
```

**Why it matters:** This dedupe-on-edit lookup keys on
`(topic_id, post_number)`. After bucket consolidation, the consolidated
`:replied` row has `post_number = first_unread_in_bucket`, not the new
event's `post_number`. If `PostAlerter` is fired twice for the same post
(e.g., on an edit), the lookup may or may not match depending on whether
the substituted `post_number` collides with the new event's.

In practice, `should_notify_previous?` returns false for `:replied`, so a
matched existing notification suppresses a duplicate — the existing
behavior. The bucket case doesn't change that materially. But it is the
sort of thing a reviewer will ask about.

**Fix:** Add a code comment explaining the intent and confirming bucket
mode doesn't change the dedupe semantics. Or leave as-is and answer in
review.

---

## 🟡 6. `Topic#nested_view?` adds a public predicate to a heavily-used model

**Location:** `app/models/topic.rb`:

```ruby
def nested_view?
  return false unless SiteSetting.nested_replies_enabled
  return false if private_message?
  nested_topic.present? || SiteSetting.nested_replies_default
end
```

**Why it matters:** Five callsites already (3 existing + 2 new) and the
predicate isn't trivial, so a method is justified — but `Topic` is a hot
model and reviewers tend to push back on additions. The method also
triggers a `nested_topic` association load if not preloaded.

**Fix options (pick one, or none):**
- Leave as-is, call out in PR description.
- Move to a concern (`app/models/concerns/nested_view.rb`) if the
  reviewer prefers.
- Add `preload(:nested_topic)` to the topic_query / topic_list paths that
  call this in loops.

**Verify:** No code change strictly required. If preloads are added, run
the `topic_list` spec to confirm no extra queries.

---

## 🟢 7. `TopicCreator#watch_topic` name is now slightly misleading

**Location:** `lib/topic_creator.rb`:

```ruby
def set_author_notification_level(topic)
  ...
end

def watch_topic(topic)
  topic.reload.topic_allowed_users.each do |tau|
    next if tau.user_id == -1 || tau.user_id == topic.user_id
    topic.notifier.watch!(tau.user_id)
  end
  ...
end
```

After the split, `watch_topic` only handles PM allowed-users (and groups).
The name "watch_topic" no longer describes what's left.

**Fix (optional):** Rename to `watch_pm_recipients` or similar. Be careful
that `TopicConverter` has a separate, same-named method — they're in
different classes but the visual collision could confuse a reviewer.

**Verify:** Grep for `:watch_topic`/`watch_topic` callers in plugins
(`grep -rn "watch_topic" plugins/`) before renaming.

---

## 🟢 8. `topic-post-badges.gjs` `has_new_replies` branch is functionally nested-only

**Location:** `frontend/discourse/app/components/topic-post-badges.gjs`:

```hbs
{{~else if @hasNewReplies~}}
  &nbsp;<a
    href={{@url}}
    title={{i18n "topic.has_new_replies"}}
    class="badge badge-notification new-replies"
  >{{this.newDotText}}</a>
{{~/if~}}
```

**Why it matters:** The branch only fires when `@hasNewReplies` is truthy,
and that arg is currently only passed from `post-count-or-badges.gjs` for
nested topics. So the new branch lives in a generic component but is
nested-only in practice. A reviewer may prefer the dot to be rendered
directly in `post-count-or-badges.gjs` to keep concerns clean.

**Fix (optional):** Inline the dot in `post-count-or-badges.gjs`:

```hbs
{{#if @topic.is_nested_view}}
  {{#if @topic.has_new_replies}}
    <span class="topic-post-badges">&nbsp;<a
      href={{@topic.lastUnreadUrl}}
      title={{i18n "topic.has_new_replies"}}
      class="badge badge-notification new-replies"
    >&nbsp;</a></span>
  {{else}}
    <ItemRepliesCell @topic={{@topic}} @tagName="div" />
  {{/if}}
{{else if (and @postBadgesEnabled @topic.unread_posts)}}
  ...
{{/if}}
```

And revert the `topic-post-badges.gjs` change.

**Verify:** Visual check in dev server that the dot still renders for
nested topics with `has_new_replies=true`.

---

## 🟢 9. No CSS for the new `.new-replies` class

**Location:** No file added; the new `<a class="badge badge-notification new-replies">`
inherits whatever `.badge-notification` provides.

**Why it matters:** Discourse themes typically style `.new-topic`
specifically. `.new-replies` is undefined visual territory. Without a
default style, the dot will look like the existing new-topic dot, which
may be the desired UX (Penar's screenshot suggested reusing the same
visual). But explicit is better.

**Fix:** Add a one-liner SCSS rule co-locating with existing
`.new-topic`:

```scss
.badge-notification.new-replies {
  // mirror .new-topic
  background-color: var(--tertiary);
}
```

(Find the existing `.new-topic` rule in
`frontend/discourse/app/styles/common/topic-list.scss` or similar and
match.)

**Verify:** Check the topic-list page in a dev server with a nested topic
that has new activity.

---

## 🟢 10. No system spec for the visit-clears-the-dot flow

**Location:** No file. Spec doc (phase 3) listed this.

**Why it matters:** I rely on (a) the existing `track_visit!` tests and
(b) the new serializer spec for the boolean. The integration that ties
them together — clicking the dot → `track_visit!` runs → next render
shows no dot — isn't covered end-to-end.

**Fix:** Add a system spec
(`spec/system/nested_topics/topic_list_dot_spec.rb` or extend an existing
nested-topic system spec):

1. Create nested topic, log in as another user, post a root.
2. Visit the topic list — assert the new-replies dot is visible.
3. Click into the topic.
4. Return to topic list — assert the dot is gone.

**Verify:** `bin/rspec spec/system/...`. Use the page-object pattern per
`CLAUDE.md` testing rules.

---

## 🟢 11. Frontend test coverage gaps for the topic-list dot

**Location:** No file. The serializer is unit-tested; the gjs branch is
not.

**Why it matters:** The branch in `post-count-or-badges.gjs` (nested vs.
flat) isn't exercised by any qunit test. Behavior is straightforward but
a small integration test would lock it in.

**Fix:** Add a qunit test in
`frontend/discourse/tests/integration/components/topic-list/...` that
renders `PostCountOrBadges` with `is_nested_view=true` and varying
`has_new_replies`.

---

## Summary

| # | Severity | One-line                                                                              | Effort |
|---|----------|---------------------------------------------------------------------------------------|--------|
| 1 | 🔴       | Flat-topic consolidated copy changes — restrict bucket data to nested topics          | 5 min  |
| 2 | 🟡       | `reply_notification_target` lazy `nested_topic` load — preload at hot callers          | 30 min |
| 3 | 🟡       | `unread_posts_in_bucket` deviates from `unread_posts` semantics — code comment         | 5 min  |
| 4 | 🟡       | Transition behavior for legacy notifications — optional cleanup predicate              | 15 min |
| 5 | 🟡       | `existing_notification_of_same_type` interaction with bucket consolidation — comment   | 5 min  |
| 6 | 🟡       | `Topic#nested_view?` is a new public predicate — concern or preload                    | varies |
| 7 | 🟢       | `TopicCreator#watch_topic` misleading name — optional rename                           | 10 min |
| 8 | 🟢       | `topic-post-badges.gjs` branch is nested-only — optionally inline                      | 10 min |
| 9 | 🟢       | No CSS for `.new-replies` — add SCSS rule                                              | 10 min |
| 10 | 🟢      | Missing system spec for visit-clears-dot                                              | 30 min |
| 11 | 🟢      | Missing qunit test for the topic-list dot branch                                      | 20 min |

Land #1 before opening the PR. The rest can be addressed in review or as
follow-ups depending on time.
