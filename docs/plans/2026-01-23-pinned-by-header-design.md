# Pinned Messages: Replace System Messages with "Pinned by" Headers

## Overview

Replace the system messages generated when pinning/unpinning chat messages with inline "Pinned by [username]" headers displayed above each message in the pinned messages list. When the current user pinned the message, show "Pinned by you" instead.

This matches the Slack approach where pin attribution is shown contextually in the pinned messages drawer rather than as system messages in the chat stream.

## Changes

### Backend

1. **Remove system message generation:**
   - `Chat::PinMessage` service — remove the `post_system_message` step
   - `Chat::UnpinMessage` service — remove the `post_system_message` step

2. **Enhance serializer:**
   - `PinnedMessageSerializer` — add embedded `pinned_by` user object (id, username)

3. **Remove unused translations:**
   - `chat.channel.message_pinned`
   - `chat.channel.message_unpinned`

### Frontend

1. **Modify `ChatPinnedMessagesList` component:**
   - Add "Pinned by" header above each message
   - Pin icon + "Pinned by username" or "Pinned by you"
   - Compare `pin.pinned_by.id` against `currentUser.id` for "you" logic

2. **New translations (client.en.yml):**
   - `chat.pinned_messages.pinned_by_user` — "Pinned by %{username}"
   - `chat.pinned_messages.pinned_by_you` — "Pinned by you"

3. **Styling:**
   - Muted/secondary text color
   - Small font size
   - Pin icon inline before text

## Out of Scope

- No changes to permissions or who can pin
- No changes to pin/unpin message bus events
- No changes to pinned messages button or unread indicator logic
