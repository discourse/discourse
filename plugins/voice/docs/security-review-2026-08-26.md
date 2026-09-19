# Security review — 2026-08-26

## Status

This review covers Voice at commit `60fc027`, with native mesh WebRTC as the
planned transport for Discourse free hosting. LiveKit is considered an optional
bring-your-own-service integration and is discussed separately.

The current recommendation is **not to enable mesh mode on free hosting until
the release-blocking findings below are resolved**.

This is a source review supported by the existing automated test suites. It is
not a substitute for testing the deployed TURN, network, browser, and hosting
configuration.

## Threat model

The review assumes:

- customer site administrators are trusted to administer their Discourse site,
  but are not trusted with access to hosting infrastructure;
- ordinary authenticated users may be malicious;
- public rooms may be joinable by every authenticated user, or by everyone when
  anonymous browsing is enabled;
- a malicious participant controls their browser and is not constrained by the
  Voice client UI;
- room presence and participant roles must be authoritative security
  boundaries, rather than advisory client state;
- denial-of-service resistance is important because the plugin will run on a
  shared free-hosting platform.

## Summary

| Severity | Finding | Hosting status |
| --- | --- | --- |
| High | A room-eligible user can establish an invisible mesh connection and receive another participant's microphone | Release blocker |
| High | Signaling, join, presence, and room capacity controls permit inexpensive amplification and resource exhaustion | Release blocker |
| Medium | A stage listener can publish audio to speakers despite lacking permission to speak | Remediated — see finding 3 |
| Medium | `logged_in_users` MessageBus delivery can expose room broadcasts to anonymous subscribers | Fix or prohibit the affected configuration |
| Operational | Mesh reveals peer IP addresses and lacks a secure ephemeral TURN-only privacy mode | Hosting/privacy requirement |
| High | The optional LiveKit URL creates a server-side request forgery boundary for customer administrators | Remediated — see finding 5 |

## Release-blocking findings

### 1. Invisible mesh microphone listener

**Severity:** High

**Status:** Remediated after this review — signaling, heartbeat, and state are
now bound to a server-attested participant session minted by `join`, rotated
by `livekit_token`, and revoked on leave/kick/TTL expiry; the relay drops
recipients without a live session and carries the serialized sender so early
offers render a visible participant. See the regression tests in
`spec/requests/voice/rooms_controller_spec.rb`
("#signal participant session enforcement").

**Affected code:**

- `app/controllers/voice/rooms_controller.rb`, `RoomsController#signal`
- `app/services/voice/signal_relay.rb`
- `assets/javascripts/discourse/lib/voice/mesh-signal-handler.js`
- `assets/javascripts/discourse/lib/voice/peer-manager.js`
- `assets/javascripts/discourse/lib/voice/presence-pending-peers.js`
- `assets/javascripts/discourse/app/services/voice-webrtc.js`

`RoomsController#signal` verifies that the sender is eligible to join the room,
but it does not require either the sender or recipient to be actively present.
It relays an authenticated sender ID to any positive recipient user ID.

For non-stage rooms, `MeshSignalHandler` deliberately accepts an offer or ICE
candidate when the sender is absent from `active_participants`. This handles a
legitimate race where signaling can arrive before a roster update, but it also
treats an offer from a non-present user as proof that the user shares the room.
The server has not established that proof.

When the victim accepts the offer, `PeerManager#create` immediately adds the
victim's local microphone track to the new peer connection. The microphone is
enabled by default for an active participant. The absent peer is retained for a
15-second grace period, during which media can flow; repeated offers can create
new connection windows.

An authenticated user who is authorized to join an open room can therefore:

1. identify an active participant from the room roster;
2. send that participant an SDP offer without joining the room;
3. receive the participant's SDP answer and ICE candidates; and
4. receive the participant's enabled microphone while remaining absent from the
   visible participant roster.

This does not bypass private-room membership: the attacker must already be
eligible to join the room. It does bypass the user's expectation that everyone
receiving room media is visible as a participant.

Existing coverage preserves the unsafe behavior:

- `spec/requests/voice/rooms_controller_spec.rb` sends signals to recipients
  who have not joined the room;
- `test/javascripts/unit/services/voice-webrtc-test.js` includes
  "honors an early offer from a participant whose presence has not propagated
  yet" and asserts that an absent sender receives an answer.

#### Design constraint

Signaling was deliberately decoupled from client roster presence: gating WebRTC
setup on the recipient's local `active_participants` snapshot caused months of
intermittent connection failures, because MessageBus roster propagation races
the first signals. That decoupling must be preserved. The fix is therefore a
**server-attested participant session** established synchronously by `join`,
not a requirement that roster presence has propagated before a signal is
accepted.

#### Required remediation

- Have `join` create a random `participant_session_id`, store it in Redis
  alongside presence, and return it to the client. This is server-authoritative
  and synchronous, so it cannot race MessageBus roster delivery.
- Require a valid, non-expired participant session for `signal`, `heartbeat`,
  and `state`; the server verifies the session belongs to the authenticated
  user and the current room instance before relaying.
- Relay signals with a server-attested session marker so the recipient can
  accept an early offer even when its local roster snapshot has not caught up.
  Do not infer room membership from receipt of a client-created SDP offer, and
  do not gate acceptance on the local roster.
- Revoke the session's signaling authority on leave, kick, or presence TTL
  expiry, and tear down the corresponding peer promptly.
- Show a server-serialized "connecting" participant for an early offer instead
  of an invisible media connection, so everyone receiving room media is
  visible.
- Regression tests must cover both the security boundary and the reliability
  fix:
  - delayed roster broadcast plus a valid participant session → offer accepted;
  - user eligible for the room but without a participant session → signal
    rejected;
  - stale session after leave and rejoin → signal rejected;
  - kick or TTL expiry → the session can no longer signal;
  - recipient leaves while an offer is queued → offer discarded.

### 2. Control-plane amplification and capacity bypass

**Severity:** High for shared/free hosting

**Status:** Remediated after this review. The implemented limits and their
rationale:

- Signaling schema: only `offer`, `answer`, and `candidate` events, with exact
  per-type shapes, validated by `Voice::SignalValidator` — an SDP of at most
  32 KiB, a candidate body of at most 2 KiB restricted to the four standard
  ICE fields, at most 25 events per recipient per request, recipients bounded
  by the room's effective capacity minus one, 1 MiB of signal body per
  request, and the unused arbitrary `metadata` field removed. Any violation
  rejects the whole batch before anything is published. The relay now
  publishes one MessageBus envelope per recipient carrying that recipient's
  ordered event batch (previously one publish per event); the receiver
  unpacks batches in order and still accepts legacy single events.
- Signaling rate limits are accounted in relayed events, not HTTP requests,
  so a full-room Trickle ICE burst passes while sustained abuse is cut off
  before MessageBus work: 30 requests/10 s, 5,000 events/min per user
  (roughly 4× a 50-person connect burst with an ICE restart), and 100,000
  events/min per room (50 users bursting at once), via the weighted
  `Voice::ControlPlaneLimiter`. The client's 75 ms candidate batching and
  200 ms HTTP batching are unchanged; it just flushes a recipient's batch
  early at 20 events to stay under the per-recipient cap.
- Capacity: presence is admitted atomically by a Lua script
  (`ParticipantTracker.add_within_capacity`) that purges expired presence,
  refreshes existing participants (even in a full room), and rejects new
  joiners at the effective capacity — the lower of `room.max_participants`
  and the new `voice_max_room_participants` site ceiling (default 50).
  Concurrent joins cannot exceed the cap; a full room returns 422.
- Join is rate limited (30/min per user) and idempotent: a repeat carrying
  the live participant session refreshes the grant without rotating the
  session, opening a second analytics session, re-firing badge/invite hooks,
  or rebroadcasting the roster. A leave carrying a superseded session is
  ignored, so a stale tab can never revoke a newer tab's session. Heartbeat
  still recovers briefly-lapsed presence under a valid session; join remains
  the only operation that grants participant authority initially.
- Other control-plane endpoints: state changes require a supported field,
  short-circuit (no write, no roster broadcast) when nothing changed, and are
  limited to 40/10 s; invalid participant-session attempts are limited to
  30/min; hand raising requires the participant session while moderator
  dismissals stay unaffected.
- Direct calls: the daily invite budget is checked before the ephemeral room
  is created, a failed ring destroys the room instead of orphaning it, live
  ephemeral rooms are capped at 10 per creator under a distributed mutex, and
  the co-presence job iterates pairs lazily under the site capacity ceiling
  instead of materializing them.

Regression tests: `spec/requests/voice/rooms_controller_spec.rb`
("#signal validation", "#signal rate limits", the join capacity/idempotency
and stale-leave tests), `spec/services/voice/participant_tracker_spec.rb`
(".add_within_capacity", including a concurrency test),
`spec/requests/voice/calls_controller_spec.rb`, and
`spec/services/voice/ephemeral_room_manager_spec.rb`.

**Affected code:**

- `app/controllers/voice/rooms_controller.rb`
- `app/services/voice/participant_tracker.rb`
- `app/models/voice/room.rb`
- `app/services/voice/signal_relay.rb`
- `app/jobs/scheduled/voice/update_co_presence.rb`
- `app/controllers/voice/calls_controller.rb`
- `app/services/voice/ephemeral_room_manager.rb`
- `app/services/voice/room_inviter.rb`

Several individually inexpensive operations can be amplified into database,
Redis, MessageBus, browser, and WebRTC work:

- `signal` has no rate limit. It accepts arbitrary batched messages and events,
  then emits one MessageBus publish per event. Signal types, recipient counts,
  event counts, SDP size, and candidate size are not bounded locally.
- `join` is not idempotent. With analytics enabled, every request creates a new
  `Voice::Session`, even while the user already has active presence. Only the
  newest session ID is retained in presence metadata.
- `heartbeat` can create presence for a user who never called `join`.
- `state` can write metadata and broadcast a full participant roster for a user
  who is eligible to join but is not present.
- `Room#max_participants` validates a configured value but `join` does not
  enforce it. This is particularly dangerous for full-mesh rooms, whose peer
  connection count grows quadratically.
- the scheduled co-presence calculation materializes every pair of active users,
  also creating quadratic work;
- direct-call room creation happens before the daily invite limiter. Once the
  invite limit is exhausted, repeated attempts can leave ephemeral rooms behind
  until cleanup.

#### Required remediation

- Atomically enforce `max_participants` when establishing presence. The check
  and add must not be separate raceable Redis operations.
- Make `join` idempotent for the current room instance and create at most one
  open analytics session per user and room instance.
- Make `join` the only endpoint that establishes presence. Require a valid
  participant session (see finding 1) for heartbeat, state changes, signaling,
  hand raising, and similar participant actions.
- Add per-user and per-room rate limits for join, state, heartbeat failures, and
  signaling.
- Allowlist `offer`, `answer`, and `candidate` signaling types and validate their
  expected shapes.
- Set explicit limits for recipients per request, events per recipient, SDP
  bytes, candidate bytes, total request bytes, and queued pending candidates.
- Apply direct-call and invite limits before creating an ephemeral room, and cap
  the number of live ephemeral rooms per user.
- Add load-oriented tests for room capacity and large/batched signal rejection.

## Important mesh findings

### 3. Stage publishing permissions are client-enforced

**Severity:** Medium

**Affected code:**

- `assets/javascripts/discourse/lib/voice/roster-handler.js`
- `assets/javascripts/discourse/lib/voice/mesh-signal-handler.js`
- `assets/javascripts/discourse/lib/voice/peer-manager.js`
- `assets/javascripts/discourse/lib/voice/remote-stream-registry.js`

Stage listeners need peer connections to speakers so they can receive the
stage. The mesh topology therefore retains a connection when either side may
speak. A modified listener client can attach a microphone track to that
connection even though the server would reject an unmute state change.

The receiving speaker registers and plays incoming microphone tracks without
checking whether the remote participant is a moderator or speaker. A malicious
listener can consequently transmit audio to speakers and moderators. The audio
is not automatically relayed to other listeners, but this still bypasses stage
moderation and enables targeted disruption.

The same trust boundary applies to other mesh media restrictions: client state
such as muted, video enabled, and screen sharing is not proof of what a
malicious browser put into its peer connection.

#### Required remediation

- On receipt of a media track, check the authoritative room role and room media
  policy before registering or playing it.
- Drop microphone, camera, screen, and screen-audio tracks that the remote role
  is not allowed to publish.
- Configure honest listener transceivers as receive-only, while treating that as
  defense in depth rather than the security boundary.
- Re-evaluate active tracks immediately after a role or room-policy change.
- Add browser tests using a listener-created audio track rather than only UI
  state transitions.

**Status:** Remediated after this review (mesh receive-side media policy).

- `remoteTrackAllowed` (`lib/voice/stage-roles.js`) is the receive-side
  boundary: before a remote track is registered or played, the sender's role
  in the server-broadcast roster and the room's media policy are checked.
  In stage rooms only moderators and speakers may deliver any media; video
  and screen-audio tracks additionally require the room's `video_allowed`.
  Disallowed tracks are stopped and never reach the stream registry, the
  audio monitor, transcription, or playback.
- Both mesh registration paths go through the guard
  (`VoiceWebrtcService#registerRemoteTrack`): `PeerManager`'s `ontrack`
  and the roster handler's video re-registration. The LiveKit path is
  unchanged: there the SFU enforces per-user publish grants server-side
  (`canPublish`/`canPublishSources` on tokens and `UpdateParticipant`).
- Re-evaluation on role change: a `role_change` message already tears down
  the peer and its streams; additionally, every roster broadcast now sweeps
  registered streams in stage mesh rooms and drops media from participants
  whose fresh role cannot publish (covers demotions that arrive only as a
  roster refresh).
- Defense in depth: honest stage listeners now create their pre-negotiated
  video and screen-audio transceivers as `recvonly` and answer speaker
  offers `recvonly` (mic m-lines were already receive-only for listeners,
  which hold no local stream). Promotions rebuild all peers, so directions
  never change on a live connection. This is not the security boundary —
  the receive-side check is.
- Tests (`test/javascripts/unit/services/voice-webrtc-test.js`): a
  listener-created microphone track arriving at a speaker is stopped and
  never registered; a speaker's microphone still plays for listeners and
  listener transceivers stay receive-only; video tracks are dropped in
  rooms whose policy disallows video and register once allowed; a roster
  refresh demoting a participant drops their already-registered media.
  Existing multi-session system specs (stage speak queue, voice rooms,
  video, subtitles) pass unchanged, confirming legitimate stage promotion
  and media flows survive the new boundary.

### 4. Logged-in-only MessageBus broadcasts may reach anonymous subscribers

**Severity:** Medium

**Affected code:**

- `lib/voice.rb`, `Voice.public_room_message_bus_targets`
- `app/services/voice/room_broadcaster.rb`
- `app/services/voice/directory_broadcaster.rb`

The `everyone`, `anonymous_users`, and `logged_in_users` automatic groups do not
have enumerable `group_users` rows. Voice handles all three by publishing
without MessageBus targets.

That is correct when access is intentionally available to everyone, but it is
not equivalent to `logged_in_users` on a site that permits anonymous browsing.
The HTTP room directory denies anonymous access while predictable, untargeted
room and directory channels can still deliver room metadata, participant
identities, and participant state to an anonymous subscriber.

#### Required remediation

- Do not treat `logged_in_users` as equivalent to an unrestricted audience.
- Add an authenticated delivery mechanism or omit sensitive payloads from
  untargeted channels.
- Until fixed, reject or host-lock the `logged_in_users` configuration on sites
  where anonymous browsing is enabled.
- Add an anonymous MessageBus test alongside the existing HTTP authorization
  tests.

## Mesh privacy and TURN requirements

**Classification:** Operational/privacy requirement

Mesh WebRTC media is encrypted between browsers, but direct ICE connectivity
reveals network information to peers. The configured STUN service also observes
the connecting public IP and request timing. The default configuration uses
public Google and Twilio STUN endpoints.

Voice provides a mesh privacy warning and enables it by default. For hosted
service use, the warning should not be customer-disableable without an explicit
hosting policy decision.

Static TURN credentials are returned to every participant and can be reused for
generic relay bandwidth. Secret-derived TURN credentials are better, but their
current 12-hour validity is long for a public free-hosting service. The current
transport policy also keeps direct connectivity enabled when secret-derived
TURN is used, so it does not provide an ephemeral-credential relay-only mode.

#### Hosting requirements

- Document peer IP disclosure and the third-party STUN defaults.
- Keep the mesh privacy warning enabled on hosted sites.
- Operate TURN with bandwidth, allocation, and abuse quotas.
- Use tenant- and user-attributable, short-lived TURN credentials; do not use a
  shared static credential for the hosting offering.
- Add a supported relay-only policy that works with secret-derived ephemeral
  credentials for customers who require peer IP privacy.
- Monitor TURN usage independently of Discourse request rate limits.

## Optional BYOK LiveKit findings

LiveKit is not part of the initial hosted offering. These findings are not mesh
launch blockers if the settings and related outbound calls are unavailable to
customer administrators.

### 5. Customer-controlled LiveKit URL permits server-side requests

**Severity:** High when exposed on shared hosting

**Affected code:**

- `config/settings.yml`
- `app/validators/voice_livekit_policy_validator.rb`
- `lib/voice/livekit/twirp.rb`
- `lib/voice/livekit/health_check.rb`
- `app/jobs/regular/voice_livekit_probe.rb`
- `plugin.rb` setting-change callbacks

The validator only requires a `ws://` or `wss://` prefix. `Twirp.post` converts
that value to HTTP(S) and performs server-side POST requests to fixed LiveKit
Twirp paths. It does not reject loopback, private, link-local, cloud metadata, or
other hosting-internal addresses. Connectivity errors can expose HTTP status and
a truncated response body to the administrator.

A customer administrator could therefore use BYOK configuration and probes to
reach services that are not otherwise exposed outside the hosting network.

#### Required remediation

- Keep the LiveKit settings locked or absent from customer administration until
  this is fixed.
- Require `wss://` in production.
- Resolve and validate every destination address, rejecting loopback, private,
  link-local, multicast, unspecified, and hosting-reserved ranges for both IPv4
  and IPv6.
- Revalidate on connection to address DNS rebinding and apply outbound network
  policy as a second boundary.
- Prefer an operator-owned egress proxy or explicit hostname allowlist.
- Do not return upstream response bodies to customer administrators.

**Status:** Remediated after this review (destination vetting via
`FinalDestination`).

- `Voice::Livekit::Twirp.post` now performs all LiveKit HTTP calls through
  core's `FinalDestination::HTTP` instead of Excon. It resolves the host
  itself, filters every resolved address against the private/loopback/
  link-local/reserved IPv4+IPv6 ranges and `blocked_ip_blocks`, and hands
  only vetted addresses to the socket layer — re-resolving on every connect,
  which also addresses DNS rebinding. `allowed_internal_hosts` remains the
  operator-controlled escape hatch for deliberate internal deployments.
- A blocked destination surfaces to admins as a fixed message ("resolves to
  an address this server is not allowed to reach"); sync calls fail closed
  (return false) without raising into the triggering request.
- New `VoiceLivekitUrlValidator` on `voice_livekit_url`: must be a bare
  ws(s):// origin with a hostname and no embedded credentials, and `wss://`
  is mandatory in production. `VoiceLivekitPolicyValidator` now requires
  the URL to pass the same check before any non-disabled policy can be
  enabled, so a pre-existing invalid URL cannot be activated.
- Upstream response bodies no longer reach customer administrators: probe
  and egress errors carry only the HTTP status code; the truncated body goes
  to the server log for the operator.
- Tests: `spec/lib/voice/livekit/room_service_client_spec.rb` (disallowed
  address refused for probes and sync calls via
  `FinalDestination::TestHelper.stub_to_fail`; probe errors exclude the
  upstream body), `spec/lib/voice/livekit/egress_client_spec.rb` (error
  results exclude the upstream body), and
  `spec/validators/voice_livekit_url_validator_spec.rb` (shape checks,
  credentials rejection, wss-required-in-production).
- Still open from this finding's hosting guidance: an operator-owned egress
  proxy / hostname allowlist as a second boundary, and keeping the settings
  hidden from customer admins on shared hosting until finding 6 is also
  resolved.

### 6. LiveKit presence and media-session lifecycle diverge

**Severity:** Medium to high when LiveKit is enabled

`RoomsController#leave` removes Discourse presence but does not remove the
participant's LiveKit media session unless the entire room becomes empty. A
modified client can remain connected to the SFU while absent from the Discourse
roster.

Kicking calls `RemoveParticipant`, but the user remains eligible to request a
new token for an open room. For self-hosted LiveKit, removal also does not revoke
the cached token. LiveKit documents that self-hosted deployments must use short
token TTLs and avoid issuing a replacement token after removal:

<https://docs.livekit.io/frontends/reference/tokens-grants/#token-revocation>

Before enabling BYOK, explicit leave should evict the SFU participant, kicks
should create a room-instance deny entry, and token issuance should honor that
entry.

## Lower-priority observations

### Contacts authorization

`ContactsController#index` requires a logged-in user and analytics to be
enabled, but does not call `guardian.can_access_voice?`. A user removed from
the allowed groups can continue retrieving their own historical top contacts,
durations, and session counts.

### Client-controlled invite attribution

`RoomsController#join` accepts `invited_by`, and `Voice::Invite.redeem!`
creates a redeemed link-invite row without proving that a signed link or pending
invite existed. A user can attribute their join to another user and influence
invite analytics or badge hooks.

Use signed invite tokens, or only redeem an existing server-created pending
invite.

### Analytics retention

Analytics are enabled by default with 400-day retention. The scheduled purge
removes sessions and co-presence, but invite history has no equivalent retention
job. User deletion deliberately retains historical rows with removed user
references.

Before hosting, document collection, export, deletion, pseudonymization, and
retention behavior for sessions, co-presence, invite attribution, and any
recording metadata.

## Positive security properties

The review found several sound foundations:

- Guardian checks consistently protect room visibility, private membership,
  room management, invitations, and most participant actions.
- authenticated state-changing endpoints retain normal Discourse CSRF
  protection;
- room descriptions use `PrettyText` cooking and templates use escaped output;
- chat content and channel availability delegate to Chat's Guardian checks;
- LiveKit participant tokens use room- and identity-scoped grants, short expiry,
  role-dependent publishing, and no data/admin grants;
- LiveKit webhooks verify a signed token and body hash before processing;
- secret TURN and LiveKit settings are not exposed as client site settings;
- mesh media travels directly between WebRTC peers rather than through the
  Discourse application server;
- browser speech-to-text is local by default rather than uploading call audio to
  a transcription service.

No obvious SQL injection, arbitrary file execution, unauthenticated room
management, or direct template XSS path was identified during this review.

## Verification performed

The following checks were run against commit `60fc027`:

- focused Ruby security-related suite: 188 examples, 0 failures;
- Voice JavaScript suite: 181 tests, 0 failures;
- production dependency audit: no reported advisories;
- full dependency audit: 11 high, 4 moderate, and 1 low advisory, all reached
  through lint/build dependency chains rather than the reviewed deployed
  runtime bundles;
- schema migrations were reviewed for current foreign-key, retention, and
  cleanup behavior;
- the plugin worktree was clean before this report was added.

Passing tests confirm the currently implemented behavior; they do not mitigate
the findings. In particular, current signaling tests explicitly permit absent
senders and recipients.

## Recommended remediation order

1. ~~Bind signaling to server-attested participant sessions (created by `join`,
   revoked on leave/kick/TTL) and add the invisible listener regression tests,
   keeping WebRTC setup decoupled from roster propagation.~~ Done — see
   finding 1's status.
2. ~~Enforce room capacity atomically; make join idempotent; add rate, shape,
   and size limits to the control plane.~~ Done — see finding 2's status.
3. ~~Enforce stage publishing policy at the receiving browser.~~ Done — see
   finding 3's status.
4. Correct logged-in-only MessageBus delivery.
5. Establish hosted TURN, privacy, retention, and monitoring policy.
6. Lock LiveKit BYOK settings until SSRF and media-session lifecycle issues are
   resolved. SSRF is done — see finding 5's status; the media-session
   lifecycle divergence (finding 6) remains open.

