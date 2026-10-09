# Ephemeral rooms — backend interface

Ephemeral rooms are short-lived `Voice::Room` records created by **other
features**, not by a user filling in the room form: the backing room for a
direct call between users, or a room spun up by an integration (e.g. an
events/livestream plugin) for the duration of an event. This document is the
contract for code that consumes them; there is no user-visible surface in the
Voice plugin itself.

## What "ephemeral" changes — and what it doesn't

Ephemeral is a **lifecycle** flag, orthogonal to `room_type` (`open`/`stage`):
a direct call is typically an ephemeral *open* room, an event stage an
ephemeral *stage* room.

An ephemeral room:

- **Never appears in discovery surfaces**: the room directory (`GET
  /voice/rooms`), directory MessageBus broadcasts on
  `/voice/rooms/index`, and hashtag autocomplete/rendering all exclude it.
  Whoever creates the room is responsible for surfacing it to its users.
- **Cannot be created through the rooms API**: the `ephemeral` attribute is
  not permitted in `RoomsController` or the admin rooms controller. The only
  way in is `Voice::EphemeralRoomManager.create!`.
- **Does not count** against `voice_max_rooms_per_user` (rooms are created
  *for* users by features), and does not satisfy the default-room seeder's
  "a room already exists" check.
- **Is reaped automatically** once it sits empty past
  `voice_ephemeral_room_ttl_minutes` (see Lifecycle below).

Everything else behaves like any other room: `show`, `join`/`leave`,
heartbeats, signaling, LiveKit transport resolution, chat sessions,
recordings, and moderation all work unchanged, and the standard Guardian
rules apply (`public` or membership gates joining; staff/creator/moderators
manage). The room page at `/voice/r/:slug` renders it, so consumers can
simply link users there.

## Creating one

```ruby
# A direct call: both parties are moderators, so either can invite more
# people mid-call (inviting is a moderator ability).
room =
  Voice::EphemeralRoomManager.create!(
    creator: caller,
    name: "Call",
    moderators: [callee],
  )

# An event room: the host runs it, the audience are plain members.
room =
  Voice::EphemeralRoomManager.create!(
    creator: host,
    name: event.title,
    public: true,
    room_type: Voice::Room::ROOM_TYPE_STAGE,
    members: attendees,
  )
```

- The creator always gets a moderator membership (standard room behavior).
- `moderators:` users get moderator memberships; `members:` users get
  participant memberships. A user in both lists stays a moderator.
- Any other `Voice::Room` attribute (`public`, `video_enabled`,
  `max_participants`, `livekit_enabled`, …) passes through as a keyword.
- Slugs get a random suffix (`call-a1b2c3d4`), so generic names never
  collide with existing rooms — don't rely on a predictable slug; keep the
  room's `id` (or the returned record) instead.

## Lifecycle

A scheduled job (every 5 minutes) walks ephemeral rooms:

- Rooms with live participants get their `last_occupied_at` refreshed.
- Rooms empty for longer than `voice_ephemeral_room_ttl_minutes`
  (default 30, measured from `last_occupied_at`, or `created_at` if never
  joined) are destroyed, including their LiveKit room and Redis presence
  state.

The TTL — rather than delete-on-empty — tolerates the gap between creation
and the first join, and a call in which everyone's presence briefly lapses
at once. Consumers must therefore treat the room as **disposable**: hold its
id, not assumptions about its continued existence, and be prepared for a
404 once a call has been over for a while. A consumer that finishes with a
room early (call rejected, event cancelled) may destroy it immediately via
`Voice::EphemeralRoomManager.destroy!(room)`, which performs the same full
teardown.

## Telling them apart

- Ruby: `room.ephemeral?`, and the `Voice::Room.ephemeral` /
  `Voice::Room.persistent` scopes.
- Serialized rooms (`Voice::RoomSerializer`) carry an `ephemeral`
  attribute, so client code can branch on it.
