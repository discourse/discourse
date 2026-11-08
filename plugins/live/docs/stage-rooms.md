# Stage rooms

A Stage room is a room where people join as **listeners** and only **speakers**
and **moderators** can unmute. Think Clubhouse or Twitter/X Spaces: the
audience asks to speak, and a moderator lets them on.

## Roles

| Role        | Mic | Camera / screen share | Notes                                              |
| ----------- | --- | --------------------- | -------------------------------------------------- |
| listener    | no  | no                    | The default. Can raise a hand (if enabled).        |
| speaker     | yes | yes, if the room allows video and their groups do | Granted by a moderator. |
| moderator   | yes | same as speaker       | Manages roles, the queue and the room.             |

Admins can always speak. Video follows the room's **Video** setting, the
site-level group capabilities, and `live_video_max_publishers`; listeners never
publish. (Earlier docs said Stage rooms had no video — they do, for speakers.)

The server is the authority: `rooms_controller#state` refuses an unmute from a
listener, and LiveKit tokens only carry publish rights for people who can speak.
Clients additionally ignore tracks from senders whose roster role cannot publish
(`remoteTrackAllowed`), which matters on mesh rooms.

## Getting on stage

There are three ways, all ending in the same role change:

1. **Request to speak.** A listener raises a hand
   (`POST /live/rooms/:id/request_to_speak`). Hands form a first-come queue,
   ordered by `hand_raised_at`, shown to everyone. A moderator approves or
   dismisses entries. The room setting **Allow requests to speak**
   (`speak_requests_enabled`) turns raising hands off.
2. **Invitation.** A moderator invites a listener who is in the call
   (`POST /live/rooms/:id/speak_invitation`). The listener sees *Join the stage*
   and *Decline* controls. Accepting
   (`POST /live/rooms/:id/speak_invitation/accept`) only works against a pending
   invitation. Invitations work whether or not requests are enabled.
3. **Direct promotion.** From the participant menu ("Make speaker") or the room's
   member list.

### Dismissal cooldown

When a moderator **dismisses** a raised hand, that listener cannot raise a hand
again for `Live::ParticipantTracker::HAND_DISMISS_COOLDOWN` seconds (30). The
request gets a 429 with the remaining time. Withdrawing your own hand never
starts a cooldown.

## Session-only vs permanent speakers

Approving a request, accepting an invitation and "Make speaker" in the
participant menu grant speaker **for the session**: `session_only` is set on the
membership. The role is dropped when the room empties (the last person leaves,
or the orphaned-session / roster jobs find it vacant), and when the user is
kicked.

- A row that was created for the grant is deleted.
- A row that already existed (for example a participant of a private room) goes
  back to its previous role (`fallback_role`), so access is not lost.
- Permanent speakers and moderators are never downgraded to session-only.
- Setting a role from the room's member list, or calling the memberships API
  without `session_only`, makes it permanent.

A speaker who leaves while others remain keeps the role if they rejoin; it is the
room emptying that ends the session.

## Demotion

Moving a speaker back to listeners (or deleting their membership) goes through
`Live::StageRoles`, which for a present participant:

- sets their roster role and broadcasts `role_change` and the roster,
- resets `is_muted`, `is_video_on` and `is_screen_sharing` in the roster
  immediately, rather than waiting for their client to report in,
- updates the LiveKit participant's permissions.

A raised hand is not cleared by demotion; it is cleared on promotion and when the
person leaves the call.

## Where the code lives

| Concern                              | Location                                                  |
| ------------------------------------ | --------------------------------------------------------- |
| Role changes, session-only cleanup   | `app/services/live/stage_roles.rb`                        |
| Hands, invitations, cooldown (Redis) | `app/services/live/participant_tracker.rb`                |
| Request / invite endpoints           | `app/controllers/live/rooms_controller.rb`                |
| Memberships API                      | `app/controllers/live/room_memberships_controller.rb`     |
| Permissions                          | `lib/live/guardian_extension.rb`                          |
| Queue UI                             | `assets/javascripts/discourse/components/live/speak-queue.gjs` |
| Listener controls                    | `assets/javascripts/discourse/components/live/call-controls.gjs` |
| Roster / hand / invitation events    | `assets/javascripts/discourse/lib/live/roster-handler.js` |

## Tests

- `spec/services/live/stage_roles_spec.rb`
- `spec/requests/live/rooms_controller_speak_requests_spec.rb`
- `spec/requests/live/rooms_controller_speak_invitations_spec.rb`
- `spec/requests/live/room_memberships_controller_spec.rb`
- `spec/system/live_stage_speak_queue_spec.rb` (needs `CI=1` locally: it opens two browsers)
- `test/javascripts/unit/lib/roster-handler-test.js`, `speak-queue-test.js`, `stage-roles-test.js`
