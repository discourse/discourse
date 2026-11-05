# Full chat composer before thread creation

Implementation plan for the Live room chat panel. Opening the panel should show
Chat's full composer immediately. The first successful send creates the original
message and its thread together; subsequent messages use the existing thread UI.
Opening or closing an unused panel creates no message or thread.

## Current behavior

`LiveChatPanel` renders a custom textarea and emoji picker until a thread exists.
`POST /live/rooms/:id/chat_session` follows the user on the configured channel and
returns the current session state, without creating content.
`POST /live/rooms/:id/chat_message` accepts text and delegates to
`Live::ChatSession.post_message!`. Under a per-room distributed lock, that service
either posts to an existing thread or creates the opening message and its thread.
The opener includes the room hashtag, and the thread carries the room name and a
`live_room_id` custom field.

After creation, the panel loads Chat's normal `ChatThread` component. That component
owns message loading, subscriptions, drafts, uploads, and its composer.
`ChatComposer` already delegates sending through `@onSendMessage`; most editor
features do not require a persisted thread. The specialized thread composer uses
the thread ID for drafts and typing presence. The surrounding thread component
also uses it for fetching, tracking, and subscriptions.

Persisted threads require an original message. Thread lookup, previews, counts,
and channel publication assume it is real. A hidden or deleted system message
would require changes to those behaviors and is outside this design.

## Intended behavior

- The empty panel keeps its current empty-state explanation and displays the real
  Chat composer, including emoji autocomplete, mentions, formatting controls,
  links, and enabled upload features.
- No chat message or thread is created by opening the panel, typing, or uploading.
- The first actual message becomes the original message. Keep its existing room
  hashtag prefix, author, thread title, and reverse link to the room.
- A message containing only attachments can start the session.
- Two participants sending at nearly the same time produce one thread. The first
  successful message is the original message; the other is a reply.
- A participant who is typing when someone else starts the conversation retains
  their text, completed uploads, selection, and focus during the transition.
- Failed sends leave the draft available. Thread loading failures after a
  successful send do not make the client resend an accepted message.
- Existing session rollover and channel permission rules continue to apply.

## Architecture

Keep the pending conversation as Live-owned client state. It has a real channel
and a `ChatMessage` draft, but no pretend thread ID and no entry in the channel's
thread cache. In particular, assigning `draft.thread` can register a thread in
`ChatThreadsManager`, so do not attach an incomplete thread object to the draft.

Add a small Chat-owned draft-only composer adapter extending `ChatComposer`.
Working name: `ChatComposerPendingThread`. It uses thread composer context so
registered thread toolbar controls remain available. Its inputs include the real
channel, draft, send callback, draft-change callback, upload activity callback,
and the existing drop target. Final argument names should follow nearby component
conventions. It must not contain room-specific logic.

Live resolves that component through the existing optional cross-plugin loading
mechanism. Chat must not import Live. The adapter supplies the composer and pane
interfaces required by the base component, using component-local sending and
textarea state where possible. Audit toolbar callbacks and modal callbacks against
this adapter rather than assuming `@onSendMessage` is the only dependency.

Keep the ordinary persisted-thread composer and send path intact. Add only narrow
Chat APIs needed to suppress typing presence in a pending context and initialize
an existing thread UI with a transferred draft. Do not introduce a general
server-side pending-thread lifecycle.

## Implementation sequence

### 1. Establish the draft-only composer contract

Implement the adapter in Chat using the existing composer template and uploader.
Do not copy its controls, textarea behavior, keyboard shortcuts, or upload code.
The adapter should provide:

- A `ChatMessage.createDraftMessage(channel, { user })` draft without a thread.
- Permission checks against the real channel and current user's Chat state.
- `context = "thread"` for toolbar compatibility, with a suitable translated
  placeholder provided by the host where needed.
- Draft persistence and reset callbacks owned by its host.
- No last-message editing, reply, or reaction shortcut target until a thread
  exists. Arrow-up must never edit a message from the containing channel.
- Escape behavior that stays in the room rather than navigating into Chat.
- Upload progress reporting so the host knows when switching is safe.
- Safe cleanup of textarea references, callbacks, and event subscriptions.

Typing presence before the thread exists is deliberately suppressed in the first
implementation. Do not use `/thread/undefined`, invent a thread ID, or publish
room typing into the channel-wide typing stream. Add a small explicit capability
on the base composer to skip both presence reporting and the replying indicator.
Once the normal thread UI mounts, its existing presence behavior resumes.

### 2. Retain pending drafts outside the panel component

Add a Live service for pending room chat drafts, keyed by user ID, room ID, and
linked channel ID. It stores the draft while the panel closes and reopens during
the current application lifetime. Clear its entries when successfully consumed,
on account changes, or when their channel association no longer applies.

Do not save a room draft through `ChatDraftsManager` with a missing thread ID:
that key represents the channel composer and would overwrite an unrelated draft.
Do not send synthetic thread IDs to Chat's draft API.

The initial scope is in-memory persistence across panel close and reopen. Full
page reload and cross-device restoration of a pending room draft are outside this
change; normal persisted-thread drafts retain Chat's existing behavior. This is
an explicit boundary to avoid adding a new backend draft schema to the composer
fix. The draft service must not retain DOM elements, upload controllers, or pane
instances.

### 3. Extend first-message submission

Update `RoomsController#chat_message` and `ChatSession.post_message!` to accept
text and an allowlisted array of upload IDs. Do not require nonblank text before
Chat validates the payload; attachment-only messages must be accepted, while a
request with neither meaningful text nor usable uploads must fail.

Pass uploads through `Chat::CreateMessage` for both branches: opening a new
thread and posting to a thread created by another participant. Reuse Chat's
upload ownership checks, message validation, moderation processing, permissions,
and message rate limiter. The client must never supply the author, channel,
room marker, or an arbitrary destination thread for this endpoint.

Validate the user's submitted content before adding the automatic room prefix,
so that the prefix cannot turn an empty or too-short draft into a valid message.
Define attachment-only formatting explicitly: the original message includes the
room reference and attachments without a dangling separator. Keep normal text
openers unchanged. Validate the final stored length too; the prefix contributes
to the actual message size.

Return the accepted `message_id` alongside the existing `channel_id` and
`thread_id` in the send response. State-only endpoints keep their existing shape.
The message ID lets the client distinguish message acceptance from the later
thread loading and presentation steps.

Preserve the distributed session lock. Recheck the current session inside it,
including rollover and deleted-original-message handling. Propagate meaningful
Chat service errors without consuming the draft.

### 4. Replace the placeholder in LiveChatPanel

Load the real channel even when session state has no thread ID. Follow the
existing server preparation flow and refresh cached channel membership as needed.
Render the new composer adapter with the room draft and a real upload drop target
beneath the existing empty state.

Remove the custom textarea, emoji insertion, Enter handling, autogrow, send button,
and associated state. Keep the panel header and guarded session refresh channel.
The open-in-chat action remains unavailable until a persisted thread exists.

Treat panel state explicitly as loading, pending, sending, activating a thread,
active, or unavailable. Network failures should retain enough state to retry the
failed operation without reposting a message already accepted by the server.
Ignore late asynchronous results after teardown or after a newer state request
has superseded them.

### 5. Make the transition preserve composition

When another user creates the thread, the existing content-free MessageBus signal
causes a guarded state fetch. Load the destination thread without immediately
replacing a pending composer that is sending or uploading. Retain the destination
as a pending transition and apply the newest applicable state when it is safe.

Before replacing the pending composer:

1. Ensure there is no active upload or first-message request.
2. Snapshot the current draft, completed uploads, selection, and whether the
   composer owns focus.
3. Initialize the real thread with that draft before its composer mounts.
4. Mount the normal thread UI and restore focus and selection when appropriate.
5. Release the pending draft only after ownership has moved successfully.

`ChatThread.setup` currently reloads a draft from ChatDraftsManager or creates a
new one. Add an optional initial-draft input so this setup cannot overwrite the
transferred room draft. Use it only for the first initialization; ordinary thread
navigation must continue to restore its own saved draft.

Never silently replace an existing nonempty draft for the same persisted thread.
If one already exists, use it as the destination and append pending room text
with a clear paragraph boundary, retaining both sets of attachments by upload
ID. Clear editing/reply metadata when merging independent drafts. Add focused
coverage for this exceptional case so neither draft disappears.

If the current user has successfully sent the opening message, clear only the
accepted draft. If thread fetching then fails, show a retry for loading the
conversation rather than a send action for the same accepted message. Do not
hold a destroyed composer's textarea reference after the awaited send callback;
a narrowly scoped base-composer guard may be needed around its post-send height
refresh.

Concurrent initial requests remain authoritative on the server. Avoid switching
components while a local send is in flight, and reconcile the response and any
queued session refresh before mounting the final thread. Preserve current
behavior for an already active thread's idle lifetime; do not redesign session
rollover in this change.

### 6. Remove obsolete presentation code and document the boundary

Remove placeholder-only SCSS and translation keys after checking all references.
Retain translated empty-state content and size the native composer using existing
Chat styles. Verify desktop and mobile layouts, light and dark modes, keyboard
focus, upload previews, and the room's Escape interception.

Update the plugin architecture documentation to describe the pending draft,
first-message endpoint, draft lifetime, and handoff. Keep comments in shared Chat
code generic and describe the composer mechanism without naming Live.

## Failure handling and consistency

The room lock prevents competing session threads, but it is not request
idempotency. This change should not silently retry a first-message POST after a
network error: the server may have accepted it even when the response was lost.
Preserve the draft, refresh session state, and expose a recoverable error. Full
exactly-once submission across uncertain network outcomes would need a separate
idempotency design; a staged message ID alone does not provide it.

Root-message creation and thread creation are currently separate service calls.
Add a failure test for thread creation after the root was saved. Ensure no
orphaned opener remains through an appropriate transaction/compensation boundary.
Audit Chat publication, callbacks, jobs, and indexing before choosing that boundary:
a database rollback alone cannot retract a MessageBus publish or an external side
effect. Do not claim atomic publication simply because a database transaction was
added. Keep this hardening limited to the first-message path and verify the
chosen cleanup behavior with injected failure.

No new database migration, synthetic original message, thread status, or periodic
empty-thread cleanup is required. Completed uploads abandoned without a message
continue through the site's existing upload cleanup behavior; do not delete a
shared upload merely because a room draft was discarded.

## Validation

Use the repository's frontend, HTML/CSS, JavaScript test, and RSpec skills for the
implementation. Load the service-authoring skill if the backend work introduces
or modifies a `Service::Base` service object.

### Backend coverage

Extend `spec/services/live/chat_session_spec.rb` and the chat contexts in
`spec/requests/live/rooms_controller_spec.rb` to cover:

- Opening and closing a panel creates zero messages and zero threads.
- Text, attachments with text, and attachment-only first messages.
- Empty, invalid, too-short, too-long, and unauthorized upload submissions.
- Upload settings disabled and upload ownership enforcement.
- Correct original-message author, room prefix, thread title, and room marker.
- Two initial sends sharing one thread, with attachments preserved in both.
- Accepted message ID returned by first and racing sends.
- Permissions revoked, channel closed, threading disabled, and rate limiting.
- Root creation followed by thread-creation failure and its cleanup behavior.
- Existing idle rollover, heartbeat liveness, deleted roots, and restricted-channel
  MessageBus behavior remain covered.

### Frontend coverage

Add focused Chat adapter tests and Live panel transition tests for:

- Native toolbar, autocomplete, formatting, and upload controls before a thread.
- No thread fetch, thread subscription, typing presence, or channel draft writes
  against an absent or synthetic thread ID.
- Room/user/channel draft isolation and close/reopen restoration.
- Selection and focus preservation when a remote thread arrives.
- Completed uploads transferred; in-progress uploads finish before switching.
- Existing thread draft preserved during the merge case.
- Duplicate clicks blocked, validation failure retaining the draft, and load
  retry after a successful send never submitting the message again.
- Late responses and callbacks after teardown handled safely.
- No accidental channel-message editing through ArrowUp or navigation on Escape.

Extend `spec/system/live_room_chat_panel_spec.rb` to exercise the complete empty
panel → full composer → first message → native thread sequence. Add a real upload
case and a two-participant case using the repository's existing session helpers.
Keep the existing-thread send test and relevant sidebar behavior coverage.

Run focused Ruby and frontend tests, then `bin/lint --fix` once on all changed
files. Inspect the UI in a browser with both empty and existing sessions. No tests
are required merely to save this planning document.

## Completion criteria

A participant can open an unused room's chat panel, use the standard composer and
upload a file, then send a first message that immediately becomes the thread's
original message. Another participant can be composing throughout that operation
without losing content or interrupting uploads. Leaving every draft unsent
creates no empty chat threads or autogenerated messages. Normal Chat and existing
Live session behavior pass their focused regression checks.
