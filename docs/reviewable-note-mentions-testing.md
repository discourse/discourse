# Testing reviewable note mentions locally

## Setup

1. Start your normal local development server with `bin/dev` and open the site.
2. In site settings, enable `enable_mentions`.
3. Prepare separate accounts for the note author (admin), a recipient admin, a
   recipient moderator, and a regular user. Use separate browser profiles or
   private windows for the recipients so you can check their notifications.
4. Create a topic with a recognizable title, such as **Reviewable mention test**.
   Flag a post as the regular user, then open that item from `/review` as the
   author. Copy its `/review/<reviewable_id>` URL for the following checks, using
   your actual local server address and reviewable ID.

Use the actual usernames of your accounts wherever the examples below say
`@recipient_admin`, `@recipient_moderator`, or `@regular_user`.

## Autocomplete and notifications

1. Open **Timeline & notes**, focus the note field, and type `@` followed by part
   of the regular user's username. Confirm that the user appears in the
   autocomplete, even though they cannot access the review queue.
2. Search for the recipient moderator and select them with the arrow keys and
   Enter. Repeat using the mouse for the recipient admin. Confirm that selections
   insert `@username` and that the note field stays usable.
3. Save a note mentioning the recipient admin and moderator. Confirm that the
   saved note appears in the timeline and that the input clears.
   Click a mention in the saved note and confirm the user card opens. Existing
   notes containing mentions should also become clickable after refreshing.
4. In each recipient's browser, open the notification menu. Expect the regular
   mention icon, the note author's username, and **Reviewable mention test** as
   the notification text. The text is the topic/content title, rather than the
   reviewable type label. Click the notification and confirm it opens the
   reviewable, rather than the original post.
5. Mention the same recipient twice in one note, including an uppercase spelling.
   Expect one notification for that note. Mentioning yourself does not create a
   notification. A new note can notify the same person again.

## Warning for inaccessible users

1. Save a note containing `@recipient_moderator @regular_user`.
2. Confirm that the note saves and a warning toast identifies `@regular_user`,
   explaining that they will not be notified because they cannot access the
   reviewable. The moderator should still receive their mention notification.
3. Check the regular user's account: it should have no mention notification for
   the note. Opening the reviewable URL should be denied.
4. Mention two regular users in one note and confirm the warning lists both.
5. With a screen reader, confirm the warning is announced. Save a note mentioning
   only accessible recipients and confirm no warning appears.

## Permissions and other reviewable titles

- **Admin-only item:** in `bin/rails console`, set
  `reviewable = Reviewable.find(YOUR_REVIEWABLE_ID)`, then run
  `reviewable.update!(reviewable_by_moderator: false)`. Mention both recipient staff accounts. Only the admin should be notified;
  the warning should include the moderator. Restore the flag to `true` afterward.
- **Private category:** move a test topic into a restricted category unavailable
  to the recipient moderator. Confirm mentioning that moderator produces the
  warning and no notification, even though they can access the queue generally.
- **Category group moderation:** enable `enable_category_group_moderation` and
  assign a group containing a regular account as a category's moderation group.
  Mention that account on an item in the category: they should receive a
  notification. Mention them on an item outside their moderated categories: they
  should receive no notification, and the author should see the warning.
- **Queued topic:** temporarily configure `approve_new_topics_unless_allowed_groups`
  to exclude the groups containing a test author. Submit a new topic
  as that author. Mention a reviewer in its note and confirm the notification
  uses the submitted topic title. Restore the setting afterward.
- **Queued reply:** use a post approval setting to queue a reply. Its mention
  notification should use the existing topic's title.
- **User reviewable:** on an account awaiting approval, mention a reviewer in a
  note. The notification text should identify the reviewed username.
- **Chat reviewable:** flag a message in a named chat channel, add a note mentioning
  a reviewer, and confirm the notification uses the channel title.
- **No content title:** on an item without a topic or title metadata, expect
  **Review** as the notification text. An item whose topic was deleted still
  uses the deleted-topic label.
- **Mention guards:** as a non-staff category moderator, mention a reviewer who
  has muted or ignored your account. They should receive no notification, and
  no access warning should appear. Staff authors retain the usual exemption.
  Mention `@system` and confirm no bot notification is created.
- **Mention limits:** lower `max_mentions_per_post` for a trusted non-staff
  category moderator, then try to exceed it. The note should fail to save with
  the usual mention-limit error and create no notifications. New users use
  `newuser_max_mentions_per_post`; staff are exempt. Restore both settings.
- **Plaintext preserved:** save a note containing literal HTML, Markdown links
  and image syntax. They should remain visible as text, with only individual
  user mentions becoming clickable.
- **Mentions disabled:** temporarily disable `enable_mentions`. Notes should
  continue to save, with no mention autocomplete or mention notifications.

## Automated checks

Run these from the repository root:

```sh
bin/rspec spec/models/reviewable_note_spec.rb spec/requests/reviewable_notes_controller_spec.rb spec/serializers/reviewable_note_serializer_spec.rb spec/models/notification_spec.rb plugins/chat/spec/models/chat/reviewable_chat_message_spec.rb

bin/qunit --standalone --browser-inactivity-timeout 120 frontend/discourse/tests/integration/components/reviewable/note-form-test.gjs frontend/discourse/tests/integration/components/reviewable/timeline-test.gjs frontend/discourse/tests/unit/lib/notification-types/mentioned-test.js
```

If Ruby tests report a missing `vendor/runtime_node_modules/moment/moment.js`,
restore the generated runtime assets from the installed dependencies:

```sh
pnpm exec node script/copy_vendored_assets.mjs
```

## Implementation notes

Mentions are extracted with the existing post analyzer, so inline/fenced code and
Discourse `[quote]` blocks do not notify recipients. Group mentions do not create
group notifications. Notes retain their original plaintext formatting: the server
escapes their text and adds profile links for existing individual usernames.
Mentions open the user card, including in older notes. Literal code and quote
syntax remains visible and may contain clickable usernames, but does not cause
mention notifications. Rendering does not invoke the Markdown engine.

Notification creation happens when the note is created, including creation through
plugin tools. The server checks both queue access and visibility of the specific
reviewable. Bot recipients and recipients muting or ignoring non-staff authors
are skipped; staff retain the standard communication exemption. Non-staff authors
use the existing trusted/new-user mention limits. Mute/ignore suppression does
not appear in the access warning. The successful create response includes `unnotified_usernames` for
the author's warning; saving a note is allowed even when some mentions cannot
notify their recipients.

The notification uses the existing `mentioned` type and links to `/review/:id`.
`Reviewable#title_for_notification(user)` supplies the topic or submitted title;
reviewable subclasses can override it for other content, as user and chat
reviewables do. Items without a topic or submitted title use the localized
**Review** fallback, while missing associated topics retain the deleted label. These are in-app notifications; post mention emails are not sent
for reviewable notes.
