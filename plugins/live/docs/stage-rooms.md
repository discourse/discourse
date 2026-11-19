# Stage Rooms

Stage rooms bring a Clubhouse / Twitter Spaces-style experience to Discourse Live:
moderators and speakers take the stage (with microphone, camera, and screen share
when enabled), while up to 200 listeners follow along in the audience and can
request or be invited to join the stage.

## Roles and permissions

| Role | Can publish audio/video | Can manage stage |
| --- | --- | --- |
| **Moderator** (room creator, room moderator, or site admin) | Yes | Yes (approve/dismiss hands, invite/promote/demote speakers, remote mute, pause requests, kick) |
| **Speaker** (permanent or session-only) | Yes | No (can voluntarily step down to the audience) |
| **Listener** (`participant` or no membership in public rooms) | No (receive-only) | No (can raise/lower hand and accept/decline speak invitations) |

Site admins joining a stage room receive an effective `moderator` role in the
live roster automatically, matching their server-side speak and management
permissions.

## Session-only speakers

- Approving a raised hand in the speak queue, accepting a speak invitation, or
  choosing **Make speaker** in the live participant menu grants a **session-only**
  speaker role (`session_only: true` on `POST /live/rooms/:id/memberships`).
- The grant is kept in Redis alongside the room's live roster, not in
  `live_room_memberships`, so it never creates or changes a membership row.
  Permanent memberships (including a private-room member's access) are untouched.
- Permanent speakers and moderators assigned in the room info member list (or
  via the memberships endpoint without `session_only`) already speak, so a
  session grant is a no-op for them.
- Session-only speakers keep their stage role across a page refresh or a leave
  and rejoin while others remain in the room. The grant ends when the room
  empties, when the room switches to open, or when the speaker is kicked,
  demoted, or steps down.

## Request-to-speak & invitations

- **Raise hand**: Present stage listeners can raise or lower their hand via the
  call controls or participant menu (`POST` / `DELETE /live/rooms/:id/request_to_speak`).
  Raised hands are ordered FIFO in the speak queue and pinned to the top of both
  the room page Audience shelf and the sidebar listener list.
- **Audio cue**: Moderators active in the call hear a short audio cue when a
  listener raises their hand.
- **Dismissal cooldown**: When a moderator dismisses a listener's raised hand,
  that listener must wait 30 seconds before raising again (HTTP `429`).
  Self-withdrawal does not start a cooldown.
- **Pause requests**: Moderators can toggle `speak_requests_enabled` in room
  settings or directly from the speak queue popover. While paused, listeners
  cannot raise their hand, while moderator invitations continue to work.
- **Invite to speak**: Moderators can invite a present listener to the stage
  (`POST /live/rooms/:id/invite_to_speak`) or withdraw the invitation
  (`DELETE /live/rooms/:id/invite_to_speak`). The listener sees an actionable
  banner and toast to **Join the stage** (`POST /live/rooms/:id/accept_speak_invitation`,
  validated against the pending Redis invitation) or **Decline**.

## Stage moderation & layout

- **Demotion cleanup**: Moving a speaker to listeners immediately clears their
  server-side `is_muted`, `is_video_on`, and `is_screen_sharing` state, stops
  their local media, rebuilds mesh topology or updates LiveKit `canPublish`
  grants.
- **Step down**: Non-moderator speakers can tap **Move to audience**
  (`POST /live/rooms/:id/step_down`) to return to the audience without leaving
  the room.
- **Mute for everyone**: Moderators can mute an active speaker for the entire
  room (`POST /live/rooms/:id/mute_participant`), sending a targeted `force_mute`
  event, updating roster state, and best-effort muting microphone tracks on
  LiveKit without revoking their stage role.
- **Stage vs. Audience layout**: The room page keeps speakers and moderators on
  stage with role badges and groups listeners into a compact Audience shelf
  below the stage. The Picture-in-Picture call widget prioritizes speakers in
  its tile slots and exposes the speak queue for moderators.
- **Live room-type transitions**: Switching a room between `open` and `stage`
  while a call is active reconciles participant roles, media permissions, and
  client audio/video streams live.
