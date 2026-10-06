# Security review — 2026-08-27

## Status

This is a second-pass review of Voice at commit `5a2543b`. It follows
`security-review-2026-08-26.md` and focuses on the native mesh WebRTC transport
planned for Discourse free hosting with hosting-operated coturn instances.

The first review's major signaling, capacity, stage-role, and LiveKit SSRF
findings have received substantial remediation. This pass did not identify a
new critical issue, but it found two High-severity ways to bypass guarantees
that the first review considered resolved.

The current recommendation remains **not to enable mesh mode on free hosting
until findings 1 and 2 are fixed and the coturn launch requirements in finding
6 are verified in the deployed environment**. Hosted video should remain
disabled until finding 4 is fixed.

This is a source review supported by automated tests and a direct Redis
reproduction. It is not a substitute for testing deployed TURN, network,
browser, observability, and hosting configuration.

## Threat model

This review retains the first review's threat model:

- customer site administrators are trusted to administer their Discourse site,
  but are not trusted with access to hosting infrastructure;
- ordinary authenticated users may be malicious and may automate requests;
- public rooms may be joinable by every authenticated user;
- a malicious participant controls their browser and is not constrained by the
  Voice client;
- presence, room capacity, participant roles, and call termination must be
  server-authoritative rather than cooperative client state;
- existing peer connections continue carrying media until a peer explicitly
  tears them down; and
- denial-of-service and tenant isolation are release concerns on shared free
  hosting.

## Summary

| Severity | Finding | Hosting status |
| --- | --- | --- |
| High | A session whose presence expired can re-enter a full room through heartbeat and exceed the room cap | Release blocker |
| High | Tokenless repeated joins bypass idempotence and create unbounded analytics/control-plane work | Release blocker |
| Medium | Access and moderation changes do not consistently revoke active media state | Fix before relying on private-room revocation or emergency call termination |
| Medium | A modified mesh peer can bypass the video publisher cap | Keep hosted video disabled until fixed |
| Medium | `logged_in_users` MessageBus broadcasts can still reach anonymous subscribers | Fix or prohibit the affected configuration |
| Operational | Twelve-hour, non-tenant-scoped TURN credentials require strict shared-coturn isolation and quotas | Hosting launch requirement |
| Low | Invite input is limited after constructing an unbounded SQL `IN` list | Harden before broad rollout |

## Release-blocking findings

### 1. A lapsed participant session can bypass room capacity

**Severity:** High for shared/free hosting

**Status:** Open

**Affected code:**

- `app/controllers/voice/rooms_controller.rb`, `RoomsController#heartbeat`
- `app/controllers/voice/rooms_controller.rb`, `RoomsController#livekit_token`
- `app/controllers/voice/rooms_controller.rb`, `RoomsController#signal`
- `app/services/voice/participant_tracker.rb`
- `app/services/voice/signal_relay.rb`

`ParticipantTracker.add_within_capacity` correctly purges expired presence and
atomically admits new participants up to the room cap. Participant sessions,
however, live for twice the configured presence TTL so that a sleeping browser
can recover after its roster presence lapses.

Heartbeat validates that longer-lived session and then restores presence with
plain `ParticipantTracker.add`, which does not enforce capacity. The optional
LiveKit reconnect-token endpoint has the same uncapped restoration behavior.
This assumes that an earlier capacity grant still reserves a slot, but roster
expiry allows a different user to take that slot before the participant session
expires.

The bypass is:

1. fill a room to capacity and retain the issued participant sessions;
2. stop heartbeats until those participants disappear from live presence;
3. let new users fill the released slots; and
4. before the old sessions expire, resume heartbeat with those sessions.

The old users are added without a capacity check. Once restored, they can keep
heartbeating and remain above the cap indefinitely. Coordinated users can
approximately double the configured room size. In mesh mode this is especially
costly because peer connections and signaling grow quadratically.

This pass reproduced the invariant break directly against test Redis. With a
configured capacity of two, the atomic admission path filled the room with two
new users, the original lapsed session remained valid, and the heartbeat
restoration primitive produced:

```json
{
  "participants": [900000002, 900000003, 900000001],
  "configured_capacity": 2
}
```

The same lifetime mismatch weakens signaling authority. `RoomsController#signal`
requires a participant session but does not require current live presence, and
`SignalRelay` accepts a recipient with a session even if their roster slot has
expired. A participant session is therefore not equivalent to a current room
slot during the second half of its lifetime.

#### Required remediation

- Replace every session-attested plain presence refresh with an atomic
  capacity-aware refresh. A fresh participant already holding a slot must
  refresh normally; a lapsed participant must reacquire a free slot or be
  rejected.
- When recovery finds a full room, revoke the stale participant session and
  make the client perform a clean join later. Do not leave a session that can
  continue signaling after its slot was denied.
- Require both a valid participant session and current server-side presence for
  signal senders and recipients. Checking Redis presence does not recreate the
  client-side roster propagation race that participant sessions were designed
  to avoid.
- Apply the same primitive to heartbeat, repeat join, and LiveKit token refresh
  so a check/add race cannot restore a slot without capacity enforcement.

Regression tests should cover:

- lapsed valid session plus available capacity → recovery succeeds;
- lapsed valid session plus a full room → recovery fails, count stays at the
  cap, and the session is revoked;
- concurrent slot replacement and heartbeat recovery never exceed capacity;
- a sender or recipient with a session but expired presence cannot signal; and
- ordinary fresh heartbeats in a full room continue to work.

### 2. Join idempotence depends on cooperative client input

**Severity:** High for shared/free hosting

**Status:** Open

**Affected code:**

- `app/controllers/voice/rooms_controller.rb`, `RoomsController#join`
- `app/controllers/voice/rooms_controller.rb`, `RoomsController#repeat_join?`
- `app/jobs/scheduled/voice/close_orphaned_sessions.rb`
- `app/models/voice/session.rb`

The idempotent join branch only runs when the request supplies the exact current
participant session ID and the user is still present. A malicious active
participant can omit that parameter. Atomic admission then returns `:existing`,
but the ordinary join path still:

- rotates the participant session;
- creates a new analytics `Session` row;
- overwrites metadata to point at only the newest analytics session;
- broadcasts a full participant roster; and
- runs join hooks and invitation-related work.

The per-user join limit is 30 requests per minute. Analytics are enabled by
default, so one account can create up to 43,200 session rows per day while
remaining in one room. Only the newest session is closed by a normal leave.
`CloseOrphanedSessions` scans every open session every five minutes, but skips
all of them while that user remains present. The attack therefore creates both
persistent database growth and an increasingly expensive recurring scan.

The previous review marked join idempotence resolved, but the implementation is
idempotent only for a client that voluntarily echoes its current credential.
Credentials cannot be treated as a reliable branch selector when the caller is
the adversary.

#### Required remediation

- Make active presence authoritative. An already-present user without the
  current session proof must not silently enter the full ordinary-join path.
  Reject it, or handle it as an explicit takeover with narrowly scoped
  semantics and a stricter rate limit.
- Maintain at most one open analytics session per `(room_id, user_id)`. Reuse
  or close the existing row before creating a replacement, and enforce the
  invariant at the database layer where practical.
- Ensure an intentional tab/device handoff closes or transfers the previous
  participant and analytics session atomically.
- Consider site-wide and source-IP limits in addition to the current per-user
  limiter for the hosted service.
- Do not rerun roster broadcasts or join hooks when admission reports that the
  participant already exists unless an authoritative state transition occurred.

Regression tests should cover:

- an active participant omitting or supplying the wrong session ID cannot
  create another open analytics session;
- repeated valid joins remain side-effect free;
- an explicit handoff, if supported, rotates the participant session while
  retaining exactly one open analytics row; and
- concurrent joins for one room/user cannot create multiple open sessions.

## Other source findings

### 3. Access revocation and call termination are not authoritative media revocation

**Severity:** Medium

**Status:** Open

**Affected code:**

- `app/controllers/voice/room_memberships_controller.rb`,
  `RoomMembershipsController#destroy`
- `app/controllers/voice/rooms_controller.rb`, `RoomsController#update`
- `app/controllers/voice/rooms_controller.rb`, `RoomsController#destroy`
- `app/controllers/voice/rooms_controller.rb`, `RoomsController#kick`
- `app/controllers/voice/admin_rooms_controller.rb`,
  `AdminRoomsController#destroy` and `#end_call`

Removing a membership always demotes a present user to `participant`. That is
reasonable for removing a role assignment in a public room, but in a private
room membership is the user's access grant. Deleting it leaves the user in
presence, retains their participant session, and broadcasts them as an ordinary
participant.

Guardian correctly denies that user on their next heartbeat, signal, or state
request. That does not immediately stop an existing mesh peer connection:
already-negotiated SRTP media continues until the other browsers receive a
roster change and tear down the peer. With the default TTL and heartbeat
cadence, the removed user can continue receiving media for approximately one
presence-expiry window.

Changing a public room to private has the same property for currently present
non-members. The room update changes database authorization but does not evict
participants who no longer qualify.

The admin `end_call` action deletes the LiveKit room, clears the transport pin,
and sends targeted `kicked` messages, but does not remove presence or revoke
participant sessions. In mesh mode it relies entirely on each browser obeying
the advisory message. Admin and room destroy similarly leave participant state
to expire. A modified client can retain its old session, and stale state can
cross into a subsequent call using the same room ID.

Finally, a normal kick removes the current session but does not deny a new join.
Join immediately clears the short-lived leave tombstone, so a user kicked from
a public room can return immediately. This may be acceptable only if "kick"
explicitly means "disconnect once" rather than moderation for the current call.

#### Recommended remediation

- Introduce one authoritative participant-eviction operation that closes the
  analytics session, removes presence and metadata, revokes participant and SFU
  credentials, clears status, broadcasts the final roster, and sends the
  targeted client event.
- Use it when private membership is removed, when an access-setting change
  makes a participant ineligible, and for kick, room destruction, and admin
  call termination.
- Add a random call-instance ID or monotonically changing epoch to participant
  sessions and signals. Rotate it on end-call so credentials from the previous
  call can never address the next one.
- Define kick semantics. If it is a moderation action, retain a deny entry for
  the current call instance or until a manager explicitly allows re-entry.

### 4. Mesh video publisher limits are advisory

**Severity:** Medium when hosted video is enabled

**Status:** Open; global video is disabled by default

**Affected code:**

- `app/controllers/voice/rooms_controller.rb`, `RoomsController#state`
- `app/services/voice/signal_validator.rb`
- `assets/javascripts/discourse/lib/voice/stage-roles.js`
- `assets/javascripts/discourse/app/services/voice-webrtc.js`
- `assets/javascripts/discourse/lib/voice/remote-stream-registry.js`

The server enforces `voice_video_max_publishers` when a client reports
`video: true` or `screen: true`. A modified mesh client does not have to report
that state before adding video tracks to its peer connections.

The receive-side policy verifies that video is enabled for the room and that a
stage sender has a speaking role. It does not require server-attested
`is_video_on` or `is_screen_sharing` state, nor does it require a publisher
reservation. The unexpected track is registered. It may remain absent from the
normal tile UI, but it still consumes peer and TURN bandwidth and browser media
resources.

The count/check/update in `RoomsController#state` is also non-atomic, allowing
honest concurrent requests to exceed the limit. SDP validation limits bytes and
event counts but does not limit audio/video/application media sections, so a
malicious offer can attempt multiple unexpected tracks.

#### Recommended remediation

- Allocate video publisher leases atomically in Redis and represent the lease
  in server-authoritative roster state.
- Accept remote video only from a participant holding a current lease, and
  stop/reject unexpected or duplicate tracks.
- Define semantic SDP limits, including the permitted number of audio, video,
  and data media sections.
- Test direct attachment of video without a state grant, concurrent publisher
  acquisition at the cap, duplicate tracks, and lease revocation.

Keeping `voice_video_enabled` host-locked to false is an adequate temporary
control for the planned voice-first mesh launch.

### 5. Logged-in-only MessageBus delivery remains open

**Severity:** Medium

**Status:** Open from the 2026-08-26 review

**Affected code:**

- `lib/voice.rb`, `Voice.public_room_message_bus_targets`
- `app/services/voice/room_broadcaster.rb`
- `app/services/voice/directory_broadcaster.rb`

`public_room_message_bus_targets` treats the `everyone`, `anonymous_users`, and
`logged_in_users` pseudo-groups identically and publishes without targets.
Untargeted MessageBus delivery reaches anonymous subscribers. This matches an
administrator's intent for `everyone` or `anonymous_users`, but not for a site
that deliberately selected `logged_in_users` while retaining anonymous web
browsing.

The result is a mismatch: anonymous HTTP requests cannot list those rooms, but
an anonymous MessageBus client can subscribe to predictable channels and
receive room directory entries, participant identities, roles, and state.

Fix the delivery distinction or prohibit `logged_in_users` in that hosting
configuration. Add an integration test that uses an actual anonymous
MessageBus subscriber rather than asserting only that a publish has no target.

## Hosting infrastructure finding

### 6. Shared coturn requires tenant-scoped credentials and defense in depth

**Severity:** Operational release blocker

**Status:** Requires plugin changes and deployed-infrastructure verification

**Affected code:**

- `lib/voice/ice_config.rb`

Voice issues standard coturn REST credentials with a 12-hour validity window
and a username shaped as `<expiry>:<user_id>`. Any authorized user can extract
the credential from a join response and use it from a separate TURN client for
the remainder of that window. TURN authentication proves entitlement to use
the relay; it does not bind traffic to a Voice room or WebRTC peer.

Coturn strips the numeric expiry prefix before applying its per-user allocation
quota. This means expiry rotation does not bypass `user-quota`, but the stable
quota identity is only the numeric Discourse user ID. If multiple hosted sites
share a coturn realm, unrelated users with the same ID share quota and
attribution. A user on one tenant can consume the quota identity used by a user
with the same ID on another tenant.

Upstream references:

- coturn quota normalization:
  <https://github.com/coturn/coturn/blob/master/src/apps/relay/userdb.c#L344-L371>
- coturn quota implementation:
  <https://github.com/coturn/coturn/blob/master/src/apps/relay/userdb.c#L619-L657>
- example configuration for `user-quota`, `total-quota`, `max-bps`,
  `bps-capacity`, peer ACLs, and transport controls:
  <https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf>

Recent coturn advisories reinforce that authenticated TURN must be treated as
an SSRF and capacity boundary:

- IPv4-mapped loopback peer bypass, fixed in 4.13.0:
  <https://github.com/coturn/coturn/security/advisories/GHSA-w4hf-cr3w-6h79>
- peer-IP ACL/translated-address bypass, fixed in 4.13.1:
  <https://github.com/coturn/coturn/security/advisories/GHSA-2x4g-wx24-48m4>
- mobility allocation-quota bypass, fixed in 4.17.0:
  <https://github.com/coturn/coturn/security/advisories/GHSA-f6hc-79w3-p8pq>

The current upstream release reviewed here is 4.17.2:
<https://github.com/coturn/coturn/releases/tag/4.17.2>.

#### Required hosting controls

- Include a stable, hosting-controlled tenant identifier in the username suffix,
  for example `<expiry>:<tenant_id>:<user_id>`. Avoid customer-controlled host
  names as the authoritative tenant ID.
- Prefer a distinct secret/realm or stronger quota boundary per tenant where
  operationally practical. A tenant-qualified username fixes per-user
  collisions but does not create per-tenant total quotas in one shared realm.
- Reduce credential validity from 12 hours to minutes and support safe
  credential refresh for ICE restarts. Existing allocations should not require
  a credential that remains mintable for the whole call duration.
- Configure nonzero `user-quota`, `total-quota`, `max-bps`, and `bps-capacity`.
  Coturn's defaults are unlimited.
- Run coturn 4.17.2 or a later patched release. Do not enable mobility. Disable
  RFC 6062 TCP relay when it is not needed; this is separate from accepting TURN
  clients over TCP/TLS.
- Explicitly deny loopback, private, link-local, multicast, ULA, cloud metadata,
  container/service, and hosting control-plane ranges for both IPv4 and IPv6.
- Enforce the same policy with network-level egress controls. Coturn cannot
  infer every deployment-specific NAT64, translator, or routed private range.
- Isolate relay hosts from databases, Redis, orchestration APIs, host agents,
  and other privileged internal services.
- Alert on allocations, ports, bandwidth, credential identities, authentication
  failures, and tenant/site attribution. Test quota exhaustion and peer ACLs
  from an untrusted client before launch.

The source repository cannot establish that these deployment controls exist.
They require a reviewed coturn configuration and network test in the hosting
environment.

## Lower-priority hardening

### Invite input is bounded after query construction

**Severity:** Low

**Affected code:**

- `app/controllers/voice/invites_controller.rb`, `InvitesController#create`

The endpoint converts and deduplicates the complete `usernames` parameter,
then places the complete list in `WHERE username_lower IN (...)`. The subsequent
`limit(10)` restricts returned users, not the size of the Ruby allocation or SQL
input list. The global request-body limit and a 10/minute per-user rate limit
reduce impact, but an authorized user can still create avoidable parsing,
allocation, and database work.

Reject more than `MAX_USERS_PER_REQUEST` names before normalization and query
construction. Add a request spec proving that an oversized list is rejected
rather than silently truncated after querying.

### Findings retained from the first review

The following lower-priority observations from `security-review-2026-08-26.md`
remain relevant and were not promoted by this pass:

- contacts authorization should use the same Voice access predicate as the
  rest of the plugin;
- client-supplied invite attribution should be replaced with a server-issued
  pending invite or signed token; and
- analytics, invite, co-presence, recording, export, deletion, and
  pseudonymization policy must be documented for hosting.

The optional LiveKit media-session lifecycle remains outside the proposed
hosted mesh configuration. The uncapped `livekit_token` presence restoration in
finding 1 should nevertheless be fixed before enabling that integration.

## Positive security properties

The post-first-review changes materially improved the design:

- signaling, heartbeat, and state require a server-issued participant session;
- leave and ordinary kick revoke that session;
- signal payloads have strict type, shape, recipient, event-count, and byte
  limits;
- per-user and per-room control-plane limits bound normal signaling requests;
- the ordinary join admission check is atomic under concurrency;
- stage receive-side policy stops unauthorized listener audio;
- LiveKit configuration has explicit URL validation and outbound request
  controls;
- Guardian checks, CSRF protection, escaped templates, and Chat delegation
  remain sound; and
- the production JavaScript dependency audit reported no known vulnerabilities.

No obvious SQL injection, arbitrary file execution, unauthenticated room
management, direct template XSS, or secret-setting exposure was identified in
this pass.

## Verification performed

The following checks were run against commit `5a2543b`:

- focused server suite covering rooms, participant tracking, memberships,
  admin room actions, and ICE configuration: 242 examples, 0 failures;
- Voice JavaScript/QUnit run: 187 tests, 0 failures;
- `pnpm audit --prod`: no known vulnerabilities;
- direct test-Redis reproduction of the capacity bypass, with scoped cleanup;
- review of current coturn quota source, configuration, releases, and 2026
  security advisories; and
- plugin diff/status checks before adding this report.

Passing tests validate the intended cooperative flow but do not mitigate these
findings. In particular, the current tests intentionally verify that a valid
session restores lapsed presence, but do not fill the released capacity before
that restoration. The end-call tests assert client messages and transport-pin
cleanup without asserting authoritative presence/session revocation.

## Recommended remediation order

1. Make all presence restoration capacity-aware and require current presence
   for signaling.
2. Make join idempotence server-authoritative and enforce one open analytics
   session per room/user.
3. Establish and test the hosted coturn credential, quota, egress, version, and
   tenant-isolation baseline.
4. Centralize participant eviction, introduce call-instance epochs, and define
   durable kick semantics.
5. Correct logged-in-only MessageBus delivery or host-lock the affected
   configuration.
6. Keep hosted video disabled until publisher leases and receive-side
   enforcement are authoritative.
7. Bound invite input before SQL construction and complete the first review's
   privacy/retention follow-ups.
