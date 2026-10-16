# Chat tool approval cards

Tools that require approval are shown in bot direct-message channels as a Chat
`confirmation` block: a heading identifying the target, a preview of the
change, the approval question and Yes/No buttons. The chat message body holds
the plain Markdown description and is rendered inside the card while it is
pending.

## Building a card

`DiscourseAi::Agents::Bot#enqueue_tool_for_approval` yields a `:chat_approval`
hash built from the tool's presentation methods. Responders pass that hash to
`DiscourseAi::AiBot::ChatToolApproval.pending_blocks(reviewable_id, info:)` and
use `info[:details]` as the message body. Calling `pending_blocks` without
`info:` keeps the legacy actions-only layout.

A card must be posted in the source request's channel and thread. A thread's
original message is also shown in the main channel, so its card may stay there;
`ReviewableAiToolAction` checks this placement before executing an action.

## Tool presentation methods

Every tool inherits defaults from `DiscourseAi::Agents::Tools::Tool`:

- `approval_title` — heading; defaults to the tool summary.
- `approval_changes` — `[{ label:, before:, after:, before_color:, after_color: }]`
  diffs; empty by default.
- `approval_details` — Markdown message body; defaults to the tool description.
- `approval_description_label` / `approval_show_description?` — label for, or
  suppression of, the body inside the card.
- `approval_question` — defaults to "Do you want to make this change?".
- `approval_parameters` — `[{ label:, value:, color: }]`; defaults to the tool
  parameters minus `reason`, with a swatch for six-digit hex colours.
- `approval_resolved_title` — optional replacement heading after the action
  ran, for tools that rename their target.

Previews run before the tool's own permission checks, so overrides must only
describe targets the requesting user can see (`previewable?`) and must never
mutate anything. Values are truncated to the schema limit; the Markdown fields
are cooked by Chat when the message is serialized.

## Resolution

Approving or rejecting keeps the card and replaces its footer with the outcome;
an execution failure is stored in the card's `error` field and the buttons stay
for a retry. `ChatToolApproval.transcript_text(message)` renders a card as plain
text for consumers that only read the message body, such as model replay.
