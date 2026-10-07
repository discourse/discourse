# Chat tool approval cards

The built-in `DiscourseAdminAssistant#tools` currently exposes 16 approval-required
tools: change_site_setting, close_topic, lock_post, unlist_topic, delete_topic,
edit_post, create_category, edit_category, change_topic_category, create_tag,
edit_tag, change_topic_tags, move_posts, suspend_user, silence_user, and
mark_as_solved. Category editing covers name, description, color, and text color
in one tool; a single approval can contain multiple changed fields.

Approval-required tools emit a shared Chat `confirmation` block containing the action
title, approval question, proposed parameters, and Yes/No actions. The chat message
body contains the change description. Chat renders that body inside the card while
it is pending, and keeps errors visible inside the card when execution fails.

The card is created by `ChatToolApproval.pending_blocks`, using data emitted by
`Bot#enqueue_tool_for_approval`. Both the AI playground and hosted-site helper bot
must pass the complete approval info to `pending_blocks(reviewable_id, info: info)`
and use the details as the message body. Calling it with only the reviewable ID
retains the legacy actions-only layout. Hosted-site also excludes confirmation
blocks from the model's conversation text when replaying structured tool context.
Approval cards must use the source request's channel. Actual thread replies require
cards in the same thread. A thread's original message also appears in the main chat,
so its approval card can stay there; hosted-site uses this placement to keep its
conversation flat. The reviewable checks this context before executing an action.
Yes and No retain the existing approve/reject action
IDs and review queue permissions. Once resolved, the card retains its title,
description, and proposed parameters. Its footer shows the outcome and the user
who acted, replacing the approval question and buttons. Older actions-only messages
retain their text-based resolution behavior.

All tools use `Tool#approval_details`, `#approval_question`, and `#approval_parameters`.
The defaults reuse the tool description, ask for confirmation, and show supplied
parameters as escaped text, excluding the reason. This includes empty strings, false
values, and arrays. Reasons remain on queued actions for review and auditing.
Valid `color` and `text_color` parameters carry a six-digit hex color for a
decorative swatch beside the value. The swatch remains visible in resolved cards.
Creation cards identify the tag or category in the title and ask “Do you want to
create this tag/category?” Their `show_description` flag is false to suppress the
redundant message-body sentence. The name is omitted from parameters; optional
properties such as description, colors, or parent category remain available for
review. Chat omits the middle section entirely when there are no properties,
changes, or errors, including after resolution. Legacy cards default to showing
the message description.
Existing cards without color metadata also preview valid hex values in `color`
and `text_color` rows.
New approval-required tools inherit the same presentation automatically.
Category edits omit fields whose proposed values are already applied; a request
with no remaining changes is rejected before an approval is queued. Description
comparison cooks both values so equivalent stored HTML and Markdown do not create
an unnecessary approval.
Category edit cards use “Editing category:” followed by a cooked category badge.
Each structured change has a translated “Changing name:” (or description/color)
label, with the old value struck through on a danger background and the proposed
value on a success background. Values are escaped text, including multiline
content. The `changes` snapshots persist after approval or rejection. The question
is the generic “Do you want to make this change?” because the heading identifies
the target. `approval_title` and `approval_changes` provide this presentation.
Tag edit cards use “Editing tag:” followed by a tag badge and the same labeled
diffs for name and description. Names preview the cleaned value that will be saved;
cleared descriptions show “Empty”. After a successful rename, the heading refers
to the new tag name so its badge still resolves, while the old/new diff is retained.
Topic category and tag changes identify the linked topic title in the heading.
Category diffs show names and their color swatches. Tag diffs compare the complete
current and proposed sets, accounting for append versus replacement and cleaned
names; an empty set is labeled “No tags”. Both omit raw ID parameter rows and
retain the captured values after resolution.
Close/reopen, delete/recover, list/unlist, and mark/unmark-solution cards also
use “Editing topic:” with the topic link. They compare explicit status, visibility,
or solution states instead of displaying boolean/ID parameter rows. Solution
previews account for multiple-solution mode and include the affected post's link
in the approval question. Deleted topics remain identifiable for recovery previews.
Suspension and silence cards use “Suspend user:” or “Silence user:” with a username mention, a bold “Duration:” label
and a concise duration (“5 days”). The optional `description_label` field renders
using the same `chat-confirmation__change` and `chat-confirmation__change-label`
markup and styles as diff labels. Each asks whether to suspend or silence the user. They have no status diff
or repeated username/duration parameter rows. An optional message to the user
remains visible for review; the reason stays in the audit record.
Post edits use “Editing post:” with the topic title and post number linked to the
specific post. “Changing content:” compares raw text with escaped multiline values;
first-post title edits also show “Changing topic title:”. The edit reason remains
on the queued action but is omitted from the card along with redundant ID rows.
Site-setting changes use “Changing site setting:” with the setting name formatted
as code, followed by “Changing value:” and the same old/new diff. Empty values are
labeled “Empty”; booleans remain explicit true/false values. Lock/unlock cards link
to the post and compare its locked state. Moving posts identifies the source topic,
compares destination titles, and lists selected post numbers; new-topic moves also
show the requested category and color when supplied. Errors are a separate
cooked `error` field so failed executions retain the diff and retry buttons.

Override the approval presentation methods when a tool can provide a clearer preview.
Do not execute a tool or mutate its target to build the preview. Markdown descriptions
and questions are cooked by Chat; parameter values are rendered as plain text.

## Manual testing with the hosted-site helper bot

With the hosted-site plugin loaded, configure an LLM in the AI admin interface and
select it as the default LLM or the admin assistant's default. Enable Discourse AI
and Chat. Keep the admin assistant's `allow_chat_direct_messages` disabled:
hosted-site owns this conversation's replies, and enabling both responders can
produce duplicate approvals and threaded replies. Onboarding configures this flag.
Transcript sync is optional and skips local setups without hosted credentials.
The response job does not retry an entire model turn after a later sync failure.
Run this in `bin/rails console` using your active admin username:

```ruby
SiteSetting.discourse_helper_bot_enabled = true
admin = User.find_by!(username: "your_username")
HostedSite::DiscourseHelperBot.onboard_admin_user(admin)
```

Onboarding creates the helper bot conversation. It does not call the LLM or create
an approval card. In that conversation, request a change to a test category, such
as “Change the name of Approval test to Approval preview.” Check the title,
current and proposed values, category badge, and Yes/No controls. Select No
and confirm the category stays unchanged; repeat and select Yes to verify the
change and the retained approval history.

Also request a site setting change to check the current/proposed value diff. Test
empty values, multiple category fields, and long descriptions. Apply pending
local database migrations before onboarding if bot creation fails on missing
user preference columns.
