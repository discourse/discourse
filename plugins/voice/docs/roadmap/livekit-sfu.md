# Optional LiveKit SFU support

This is the "SFU integration (future, separate effort)" scoped out of
[video-screenshare.md](./video-screenshare.md). It is written to be executed by
a coding agent, PR by PR (§9). Line references are against plugin commit
`123a826` (2026-07-08) — re-verify before editing; treat method names as the
stable anchors.

**Goal**: enterprise customers who need many simultaneous video calls can
deploy their own [LiveKit](https://livekit.io) server and point the plugin at
it. Everyone else keeps the current pure-P2P mesh, byte-for-byte.

**Non-goals**: mid-call mesh↔SFU migration, LiveKit Cloud billing integration,
recording/egress (the token/room-name plumbing here is its prerequisite,
nothing more), replacing mesh as the default.

---

## 1. Design summary

LiveKit is added *beside* the mesh as a per-room transport branch inside
`voice-webrtc.js` — not as a formal transport-interface refactor. The mesh
path (glare handling, offer retries, ICE-restart detection, transceiver
pre-allocation, join-race buffering in `peer-manager.js` / `signaling.js`) is
battle-tested and is **not extracted, rewritten, or adapterized**. The service
already has a natural seam, proven at three points:

- **Outbound**: media reaches the transport at exactly three places —
  peer creation (`peer-manager.js:209–250`), `#replaceTrackOnAllPeers`
  (service ~:2630), and `#syncVideoSenders` (~:1414).
- **Inbound**: all remote media enters through `#registerRemoteTrack(roomId,
  userId, track, streams)` (~:2395) and leaves through `#removeRemoteStream`
  (~:2454). Everything downstream (per-user MediaStream registry,
  `attachStream`, volume/deafen, `AudioMonitor` speaking detection) operates on
  plain MediaStreams.
- **Control**: UI components consume only the service's public API; nothing
  touches `RTCPeerConnection`.

So:

1. Each active room instance is tagged with a transport (`"mesh"` |
   `"livekit"`), **decided by the server** in the join response and pinned in
   Redis for the life of the room instance.
2. Mesh-specific call sites get `if (this.#isMeshRoom(roomId))` guards — pure
   additive guards that are tautologies for default installs.
3. One new class, `LivekitRoomSession`, connects `livekit-client` to the *same*
   callbacks `PeerManager` already uses (`#registerRemoteTrack`,
   `#removeRemoteStream`), so the remote-media registry and every UI component
   are untouched.

Presence, sessions, badges, co-presence, user status, admin stats, sound
effects, idle/AFK, and the roster UI all ride the existing REST
join/heartbeat/leave/state + Redis + MessageBus stack, which never touches
media — they are **identical on both transports by construction**.

## 2. Key decisions

| Decision | Choice | Why |
|---|---|---|
| Presence/sessions | Keep REST heartbeat + Redis + MessageBus for both transports; LiveKit webhooks are an optional reconcile-only backstop (PR 8) | Sessions, badges, co-presence, user status, admin stats, anon directory all key off `ParticipantTracker` + `Voice::Session`. Webhooks-as-authority would fork every consumer and break anon directory viewing. Heartbeats guarantee identical analytics on both transports with zero change. |
| LiveKit JS delivery | Vendored ESM bundle under `public/javascripts/livekit/`, dynamic `import()` at join time | Matches the mediapipe precedent (`background-blur.js:39–51` dynamically imports vendored assets by URL). Zero LiveKit bytes shipped/parsed on the P2P path; no coupling to core's build. Pinned + checked in, rebuilt via a script like `scripts/build-dtln-worklet.sh`. |
| Ruby dependency | No gem. Mint JWTs with core's `jwt` gem; hand-roll three Twirp-JSON RoomService calls (~60 lines) | The token is a stable, documented HS256 JWT; RoomService accepts plain JSON POSTs to `/twirp/livekit.RoomService/*` with a `roomAdmin` JWT bearer. Avoids plugin gem pinning/boot friction. |
| Transport policy | Server-decided at join; pinned per live room instance; policy enum `disabled \| per_room \| all_rooms`. No threshold-based auto-cascade | Mid-call mesh→SFU migration requires dual-connection handoff — maximum risk, zero-regression antithesis. Static per-room-instance resolution covers the enterprise ask ("our town-hall room uses the SFU"). A static size-based variant is a 5-line resolver addition later if demand appears. |
| Mute/PTT semantics | Keep `track.enabled` flipping on LiveKit too (silence frames through SFU, DTX-suppressed); do not use LiveKit `setMuted` | Identical code path on both transports (`toggleMute` ~:652, PTT ~:2767); zero divergence in PTT latency. Roster mute state already travels as presence metadata via `POST /state`, not media state. |
| SDK options | `adaptiveStream: false`, `dynacast: true`, audio auto-subscribe on | `adaptiveStream` keys quality/pausing off attached-element visibility — incompatible with service-owned elements (would pause "invisible" video). `autoSubscribe: false` for audio risks a subscription bug meaning silence — the worst failure mode for a voice product. |
| Client secrets | None of the new settings are `client: true` | URL + token reach the client only through the join response of rooms actually resolved to LiveKit. (Deliberately not repeating the TURN-credential-to-every-client pattern of `settings.yml:30–33`.) |

## 3. Transport seam contract

The exact call sites in `voice-webrtc.js` that branch on transport.
`LivekitRoomSession` must satisfy the right-hand column.

### Service → transport (outbound)

| Call site (mesh today) | LiveKit branch |
|---|---|
| Peer create/destroy diff in `#handleParticipants` (~:1960–2012) → `#createAndOfferPeer` | None — SFU has no per-peer setup. Guard the block. **But** the roster diff still runs for livekit rooms to drop registry entries for identities absent from the roster (§5, ghost-participant rule). |
| `#replaceTrackOnAllPeers(newTrack)` (~:2630) — NS toggle / mic switch / gate crossing | `session.replaceAudioTrack(newTrack)` → `LocalAudioTrack.replaceTrack()` |
| `#syncVideoSenders` (~:1414) — per-watcher `replaceTrack` | `session.syncLocalVideo(videoTrack, screenAudioTrack, kind)` → publish/unpublish; receive gating moves to the subscriber side |
| `#applyVideoQuality` / `#applyScreenAudioQuality` (~:1462, 1528) — mesh watcher-count bitrate ladder | Replaced by publish options + subscriber layer selection (§5, quality rules) |
| `setWatching(roomId, watching)` (~:1141) — POST `/state` + publisher-side gating | Keep the POST (roster flags drive tiles on both transports) **plus** `session.setVideoSubscriptionsEnabled(watching)` |
| `#reconnectAllPeers()` on role change (~:2248) | `session.refreshPublications()` — publish/release mic per new can-speak |
| `leave()` → `#teardownRoom` (~:1704) | `session.disconnect()`, drop from session map. Existing peerManager/signaling teardown calls are no-ops for livekit rooms (empty maps) — no guards needed. |
| `iceServers` / `iceTransportPolicy` getters (~:226–267) | Unused — LiveKit brings its own ICE/TURN. Getters stay mesh-only, unguarded. |

### Transport → service (inbound) — the same callbacks PeerManager receives

| LiveKit event | Service callback |
|---|---|
| `RoomEvent.TrackSubscribed(track, pub, participant)` | `#registerRemoteTrack(roomId, userId, track.mediaStreamTrack, streamsArg)` where `streamsArg = []` when `pub.source === ScreenShareAudio` — preserves the "bare audio track = screen audio" convention (~:2414) with zero change to `#registerRemoteTrack` — else `[participantStream]` |
| `RoomEvent.TrackPublished` | Apply current watching state to the new publication: camera/screen/screen-audio publications created while `setWatching(false)` must start **unsubscribed**; microphone publications are always subscribed |
| `RoomEvent.TrackUnsubscribed` / `ParticipantDisconnected` | `#removeRemoteStream(roomId, userId)` (~:2454) |
| `RoomEvent.Disconnected(reason)` | `DUPLICATE_IDENTITY` → **local-only teardown** (§5); other terminal reasons → reconnect ladder (§7d), then `leave(room)` + toast |
| `Reconnecting` / `Reconnected` | Log + tick `connectionRevision` |
| `connect()` rejection | Client-unreachable-SFU failure path (§7f) |

`userId` mapping: LiveKit `participant.identity` = `String(user.id)`. The
session parses it back to a number before invoking callbacks so registry keys
match roster participant ids — `remoteStreamFor(roomId, userId)`
(video-tile.gjs) works unchanged.

### Explicitly unchanged

`lib/voice/peer-manager.js`, `lib/voice/signaling.js`,
`room-message-queue.js`, all pipeline libs (`noise-suppression.js`,
`input-gate.js`, `background-blur.js`, `audio-monitor.js`, `media-devices.js`,
`ptt-manager.js`, `ptt-utils.js`, `sound-effects.js`), every component
(call-controls, call-widget, room-page, video-tile, voice-canvas, chat-panel,
settings modals, sidebar), all initializers, `voice-rooms.js`, and the whole
public service API consumed by the UI
(`join/leave/toggleMute/toggleDeafen/toggleCamera/toggleScreenShare/attachStream/attachVideoStream/remoteStreams/remoteScreenAudioStreams/remoteStreamFor/connectionStateFor/setWatching/canPublishVideo/videoAllowedIn/setInputDevice/setOutputDevice/setVideoInputDevice/localStream/localVideoStream/localVideoKind/audioEnabled/deafened/ptt*`).

## 4. Server changes

### Settings (`config/settings.yml`, after the TURN block)

```yaml
voice_livekit_url:            # wss://livekit.example.com — empty = unavailable
  default: ""
voice_livekit_api_key:
  default: ""
voice_livekit_api_secret:
  default: ""
  secret: true
voice_livekit_room_policy:
  default: "disabled"
  type: enum
  choices: [disabled, per_room, all_rooms]
  validator: "VoiceLivekitPolicyValidator"
voice_livekit_room_prefix:    # LiveKit room-name namespace override
  default: ""
voice_livekit_mesh_fallback:  # opt-in: empty room + mint failure → pin mesh
  default: false
```

None are `client: true`. `VoiceLivekitPolicyValidator` follows core's
`lib/validators/*_validator.rb` convention: refuses any policy other than
`disabled` unless `voice_livekit_url` (must be `ws://` or `wss://`),
`voice_livekit_api_key`, and `voice_livekit_api_secret` are all present,
with a specific translated error per missing field (`server.en.yml`). Admins
get config-time failure, not first-join failure.

`plugin.rb` serializes one Site attribute next to `voice_public_access`
(plugin.rb:90): `voice_livekit_per_room_available` = configured **and**
policy == `per_room`. It exists solely to gate the room-form checkbox — the
client never needs the policy enum itself.

### New: `lib/voice/livekit.rb`

```ruby
module Voice::Livekit
  def self.configured?         # url + key + secret all present
  def self.available_for?(room) # configured? && (all_rooms || (per_room && room.livekit_enabled))
  def self.room_name(room)
    # default: "#{RailsMultisite::ConnectionManagement.current_db}-r#{room.id}"
    # (room id, not slug — slugs are mutable); voice_livekit_room_prefix overrides the db prefix
  end
  def self.mint_token(user:, room:, guardian:)  # HS256 JWT via core's `jwt` gem
end
```

Token claims — least privilege, explicit:

- `iss`: api key, `sub`: `user.id.to_s`, `name`: username, `exp`: now + 10 min
- `video`: `room` = room_name, `roomJoin: true`, `canSubscribe: true`,
  `canPublish` = `guardian.can_speak_in_voice_room?(room)`
  (guardian_extension.rb:86–91), `canPublishSources` = mic always (when
  canPublish) + `camera`/`screen_share`/`screen_share_audio` iff
  `room.video_allowed?`, `canPublishData: false`,
  `canUpdateOwnMetadata: false`, and explicitly `roomCreate: false`,
  `roomList: false`, `roomAdmin: false`, `roomRecord: false`,
  `recorder: false`, `hidden: false`.

A leaked token can only join one room, as one user, for ≤10 minutes. Guardian
remains the sole authority: tokens exist only for users who passed
`ensure_can_join_voice_room!`. `voice_video_max_publishers` stays enforced
where it is today (`rooms_controller#state`, rooms_controller.rb:207–210) —
it's a roster-flag gate, transport-independent.

### Transport pin: `app/services/voice/participant_tracker.rb`

(NOT `lib/voice/` — the class lives in app/services, `KEY_NAMESPACE =
"voice:room"`, `SAFETY_TTL = 30.minutes` at :5–7.)

- New Redis key `voice:room:{id}:transport`; `pin_transport!(room_id,
  transport)` uses `SET NX`; `pinned_transport(room_id)`;
  `clear_transport_pin(room_id)`.
- TTL = `2 × SiteSetting.voice_participant_ttl_seconds` (settings.yml:19,
  default 30 s), refreshed on every join/heartbeat — a crashed room self-heals
  in ~60 s instead of holding a stale transport.
- Cleared explicitly when the room empties: on last leave in
  `rooms_controller#leave`, with a backstop in
  `Jobs::PublishRoomParticipants` (app/jobs/scheduled/publish_room_participants.rb),
  which already sweeps recently-active rooms and can detect emptied ones.
  Room-emptied cleanup also fires best-effort `delete_room` (below).

### `app/controllers/voice/rooms_controller.rb`

- **`#join`** (:95–128): before the presence add —
  `transport = pinned || (Livekit.available_for?(room) ? "livekit" : "mesh")`;
  pin it. Response gains `transport:` and, for livekit,
  `livekit: { url:, token: }`. Mint failure handling per the §7 table.
- **New `#livekit_token`** (`POST rooms/:id/livekit_token` in
  `config/routes.rb`): `ensure_can_join_voice_room!` +
  `RateLimiter.new(current_user, "voice-livekit-token", 10, 1.minute)`
  (network-flap rejoins are the legitimate burst case). The endpoint
  **re-adds presence + refreshes metadata itself** (same authz as heartbeat) —
  it must not require existing Redis presence, because its one consumer is the
  reconnect ladder that runs precisely when the 30 s presence TTL has lapsed.
  If the pin is gone or re-resolved to mesh, return a distinct
  `410 Gone` ("room instance ended") — the client stops the ladder, leaves
  cleanly, and shows a rejoin toast.
- **`#signal`** (:254): 422 when the room's pinned transport is livekit
  (defense in depth).
- **`#leave`**: clear the transport pin when the leaver was the last
  participant.
- **`#kick`** (:228): after the existing broadcasts, best-effort
  `RoomServiceClient.remove_participant` (rescued + logged) — the client-side
  `kicked` handler (~:2047) already forces leave; this evicts the media
  session too.
- **`#destroy`**: best-effort `delete_room`.

### `app/controllers/voice/room_memberships_controller.rb`

On role change in a livekit-pinned room, best-effort
`RoomServiceClient.update_participant(permission: { can_publish: ... })` so a
promoted stage listener can publish without reconnecting (client sees
`ParticipantPermissionsChanged` → `refreshPublications()`). Fallback if the
call fails: client re-mints via `livekit_token` and reconnects.

### New: `lib/voice/livekit/room_service_client.rb` (~60 lines)

Twirp-JSON POSTs — `RemoveParticipant`, `UpdateParticipant`, `DeleteRoom` — to
`/twirp/livekit.RoomService/*` with a short-lived `roomAdmin` JWT bearer, via
core HTTP conventions (`FinalDestination`/Excon). Timeout 2 s, always rescued:
LiveKit being down must never fail a Discourse request. Every failure log
prefixed `[voice-livekit]`.

### Admin: emergency "End live call"

Admin action (status panel or admin room list) that: calls `delete_room`,
clears the transport pin, and iterates current participant ids publishing the
**existing per-user `kicked` message** (`RoomBroadcaster#publish_kick`,
room_broadcaster.rb:69–75) to each — zero client changes, `#handleKicked`
already forces leave. Rejoining users re-resolve the transport. Also ship
`rake voice:clear_transport_pins` for emergencies.

### Admin health/diagnostics (own PR)

1. Flipping LiveKit config enqueues a one-shot connectivity-probe job whose
   result surfaces to the admin within seconds, not at first user join.
2. `GET /admin/plugins/voice/livekit/status` (AdminConstraint) returns:
   settings-present booleans (never values), a token self-mint check, a
   RoomService `list_rooms` probe with latency + error string,
   `last_webhook_at`, and currently pinned livekit rooms with a
   Redis-presence vs LiveKit `list_participants` diff — the triage view for
   "connects but no media" / ghost-participant support cases.
3. Rendered as a card in `admin/assets/javascripts/admin/components/voice-dashboard.gjs`.
4. A request spec asserts the API secret never appears in any serializer or
   status payload.

### Per-room policy surface

- Migration: `add_column :voice_rooms, :livekit_enabled, :boolean,
  default: false, null: false` (load `.skills/discourse-migration` first).
- Permit `livekit_enabled` in both room param lists; expose on
  `room_serializer.rb` to managers only. The live instance's transport is
  never serialized — clients learn it at join.
- `components/voice-room-form.gjs`: one FormKit checkbox ("Use media server
  (SFU)") gated on `Site.voice_livekit_per_room_available`. Stale-form edge:
  a form loaded before an admin flips policy can still submit
  `livekit_enabled` — harmless (resolver re-checks policy at join); pin with a
  request spec that the attribute is accepted-but-inert when policy no longer
  allows it.

### Webhooks (optional, PR 8 — reconcile-only)

`POST /voice/livekit/webhook` (engine-scoped, skips CSRF + login), verifies
the `Authorization` JWT (HS256, api key/secret) + SHA256 body hash. Handles
`participant_left` **and** `participant_connection_aborted` by early-expiring
Redis presence that LiveKit knows is gone (same removal path heartbeat-TTL
uses); `room_finished` clears the transport pin. Every verified webhook
`SETEX`es `voice:livekit:last_webhook_at` for the status panel (stale = warning,
never error). Never creates presence; never touches `Session` rows —
`CloseOrphanedSessions` remains the correctness backstop on both transports.

## 5. Client changes

### New: `lib/voice/livekit-session.js` (~350 lines)

One instance per active LiveKit room, owned by the service, callback-injected
in the same style as `PeerManager` (which is what makes it unit-testable):

```js
export default class LivekitRoomSession {
  constructor({ roomId, currentUserId,
    loadSdk,            // async () => livekit-client module (injectable for tests)
    getLocalStream, getLocalVideoTrack, getLocalScreenAudioTrack,
    onTrack,            // → #registerRemoteTrack
    onParticipantGone,  // → #removeRemoteStream
    onDisconnected,     // (reason)
    onConnectionChange, // ticks connectionRevision
    mintToken,          // async () => ({ url, token }) — POST livekit_token
  }) {}
  async connect(wsUrl, token)   // import SDK, new Room({ adaptiveStream: false, dynacast: true }), connect, publish current tracks
  async disconnect()
  async replaceAudioTrack(track)
  async syncLocalVideo(videoTrack, screenAudioTrack, kind)
  setVideoSubscriptionsEnabled(bool)   // + TrackPublished handler applies it to late publications
  async refreshPublications()          // re-evaluate mic publish after role change
  async reconnectWithToken()           // ladder: 3 attempts, backoff, mintToken() each round
  static isBrowserSupported()          // SDK support check; unsupported → translated toast, not an opaque SDK error
}
```

Default `loadSdk`:
`import(getURL("/plugins/voice/javascripts/livekit/livekit-client.mjs"))` —
never evaluated for mesh rooms.

**Publish rules**
- Mic: `publishTrack(localStream.getAudioTracks()[0], { source: Microphone,
  dtx: true, red: true })`. The pipeline's AudioWorklet-destination tracks
  publish cleanly — LiveKit accepts arbitrary `MediaStreamTrack`s. Mute/PTT
  keep flipping `track.enabled`, untouched.
- Camera: `{ source: Camera, simulcast: true, videoEncoding: <720p preset,
  maxFramerate 24> }`; screen: `{ source: ScreenShare, simulcast: true,
  screenShareEncoding: <maxFramerate 15> }` — mirror the capture-time caps and
  contentHints currently set around ~:1279–1287, else SDK defaults apply.
  Screen audio: `{ source: ScreenShareAudio }` + 128 kbps.
- Publish mic only when the user can speak (stage rooms) — mirrors
  `#canSpeakInRoom` (~:335); token grants enforce it server-side regardless.

**Subscribe/quality rules** (replaces the mesh bitrate ladder — do not skip;
with `adaptiveStream: false` the SDK defaults every subscription to the HIGH
simulcast layer, which would regress downlink vs the mesh's 400 kbps ladder in
big rooms):
- Screenshare subscriptions: `setVideoQuality(HIGH)`.
- Camera subscriptions: MEDIUM by default; LOW when the room has more than ~6
  active video publishers (same threshold the mesh ladder uses at ~:1462).
  Re-evaluate on publisher-count changes; the service already tracks
  `videoPublisherCount(roomId)`.
- `setWatching(false)` unsubscribes camera/screen/screen-audio publications;
  mic publications are **always** subscribed. Late publications (published
  while not watching) must be created unsubscribed via the `TrackPublished`
  handler.

**Disconnect handling**
- `DUPLICATE_IDENTITY` (same user joined from a newer tab): **local-only
  teardown** — session disconnect + client state cleanup that explicitly
  **skips `DELETE /leave`**. A normal `leave()` here would close the *new*
  tab's `Session` row (its id just overwrote `metadata[:session_id]` —
  rooms_controller.rb:377–384), drop the user from the roster until the next
  heartbeat, and clear their user status. Implement as an option on `leave`
  (e.g. `leave(room, { skipServer: true })`) or a dedicated local teardown.
  Unit test must assert no DELETE is issued.
- Other terminal reasons / mid-call hard-down: reconnect ladder — up to 3
  attempts with backoff, each awaiting a fresh `mintToken()`; on `410 Gone`
  stop immediately, local teardown + rejoin toast; after exhaustion,
  `leave(room)` + toast.

### Modified: `app/services/voice-webrtc.js` (~200-line diff, all additive/guarded)

1. State: `#roomTransports = new Map()` (roomId → transport, default `"mesh"`
   when untagged so pre-tag messages/tests/old servers behave identically),
   `#livekitSessions = new Map()`, helper `#isMeshRoom(roomId)`.
2. `join(room)` (~:357): read `data.transport ?? "mesh"` and `data.livekit`
   from the join response. After mic acquisition and the active-mark (~:463),
   for livekit: `LivekitRoomSession.isBrowserSupported()` check, construct +
   `connect(url, token)`. **On connect failure: fire
   `ajax(.../leave, { type: "DELETE" })` before `#handleJoinFailure(room.id)`**
   — the exact precedent of the mic-failure path at ~:431–437; otherwise the
   user ghosts in the roster for the presence TTL and the Session row dangles.
   Distinct translated toast ("your network cannot reach the voice server" —
   different from the server-side mint-failure copy) + `[voice-livekit]`
   console log. **No mesh fallback client-side ever** — other clients may
   reach the SFU fine; falling back would split future joins.
3. `#processRoomMessage` (~:1735): `signal` case early-returns for livekit
   rooms.
4. `#handleParticipants` (~:1941): guard the peer create/destroy block and
   presence-pending machinery as mesh-only. Roster sync, join/leave sounds,
   `#syncRemoteVideoTracks`, `#syncVideoSenders` stay common. **Livekit
   ghost-participant rule**: for livekit rooms the roster diff additionally
   drops registry entries (calls `#removeRemoteStream` and unsubscribes) for
   identities absent from the roster — mesh gets this for free by destroying
   the peer; without it, a participant expelled from the roster (heartbeat TTL
   expiry, kick with failed `RemoveParticipant`) stays audible forever because
   voice-canvas plays every stream in `remoteStreams`.
5. `#handleRoleChange` (~:2090): mesh → existing `#reconnectAllPeers`; livekit
   → mic acquire/release per new role + `session.refreshPublications()`.
6. `#replaceTrackOnAllPeers` (~:2630): prepend fan-out to `#livekitSessions`;
   the existing sender loop is a natural no-op for livekit rooms.
7. `#syncVideoSenders` (~:1414) / `#broadcastVideoState` (~:1542): livekit
   rooms delegate to `session.syncLocalVideo(...)`; the `POST /state`
   broadcast stays identical on both transports.
8. `setWatching` (~:1141): after the existing POST, call
   `session.setVideoSubscriptionsEnabled(watching)` for livekit rooms.
9. `leave` (~:512) / `#teardownRoom` (~:1704): disconnect + delete session;
   support the `skipServer` local-only variant.
10. Inbound wiring: bind session callbacks to `#registerRemoteTrack` /
    `#removeRemoteStream` exactly as PeerManager is bound (~:137–141); add the
    disconnect-reason handler.

**Not touched**: `#handleSignal`, glare/ufrag logic, `#createAndOfferPeer`,
`#shouldEngagePeer`, `iceServers`, PeerManager/SignalingManager construction,
the entire local audio/video pipeline, remote registry internals,
attach/volume/deafen/PTT/idle/audio-monitor code.

### New: vendored SDK + build script

- `public/javascripts/livekit/livekit-client.mjs` — single-file ESM bundle of
  pinned `livekit-client` v2.x, built by new `scripts/build-livekit-bundle.sh`
  (esbuild or webpack — webpack is already a devDependency) and checked in,
  exactly like `dtln-worklet.js`.
- `package.json`: `livekit-client` as **devDependency only** (build-time
  input, never in the app graph) + a `build:livekit` script.
- CI grep guard: no static import of `public/javascripts/livekit/` anywhere
  under `assets/` — converts "zero LiveKit bytes on the P2P path" from a
  review-time promise into a regression-tested invariant.

## 6. Transport resolution

Server-only, at join:

```
pinned = redis GET voice:room:{id}:transport
if pinned                                        → use pinned
elsif Livekit.available_for?(room)               → "livekit", pin
else                                             → "mesh", pin
```

- **All participants share one transport** — guaranteed by the pin; joiners
  after the first ignore current settings. No client-side choice, no mixed
  room, ever.
- **Config changes affect only the next room instance** (first join after the
  room empties / pin expires). Live calls are never migrated or split. Setting
  descriptions state this explicitly. Emergency levers: admin "End live call",
  `rake voice:clear_transport_pins`.

## 7. Failure-mode policy

| # | Failure | Behavior |
|---|---|---|
| a | Token mint fails, room EMPTY | Join fails: specific translated toast ("Voice server unavailable — contact your administrator"), `[voice-livekit]` log, status panel red. If `voice_livekit_mesh_fallback` is on (opt-in — silent degradation hides outages from ops) **and the room is empty**, pin mesh for this call and proceed. |
| b | Token mint fails, room OCCUPIED on livekit | Join fails with the same toast. Never fall back — would split the call. |
| c | Mid-call SFU blip | SDK auto-resume; heartbeats keep presence/sessions/badges unaffected throughout. |
| d | Mid-call SFU hard-down | Reconnect ladder: 3 token-refetch attempts with backoff via `livekit_token`; then `leave()` + toast. |
| e | Webhooks undeliverable | Zero correctness impact; status panel shows stale `last_webhook_at` as a warning. |
| f | Mint succeeds but the CLIENT can't reach the SFU (corporate firewall blocking WSS/UDP — the most common enterprise failure) | Distinct toast ("your network cannot reach the voice server"), immediate `DELETE /leave` cleanup, `[voice-livekit]` console log. **No mesh fallback even under (a)'s setting** — other clients may reach the SFU fine. |
| g | Pin says livekit, config half-deleted | Same as (a)/(b) — 503 with clear error; validator (§4) makes this hard to reach. |
| h | Reconnect ladder finds pin gone/re-resolved (room instance ended while client slept) | `livekit_token` returns `410 Gone`; client stops the ladder, local teardown, rejoin toast. |

## 8. Feature preservation matrix

| Feature | Mesh mechanism | On LiveKit | Change |
|---|---|---|---|
| Mute | `track.enabled` + `/state` metadata | Identical (DTX silence through SFU) | None |
| Deafen | Element-level `muted` on all sinks + mic force-mute | Identical — same service-owned elements | None |
| PTT / input gate | `track.enabled` flips (~:2767); WebAudio gate → `#replaceTrackOnAllPeers` | Identical; fan-out extended | 1 branch |
| DTLN noise suppression | Worklet pipeline → new track → `#replaceTrackOnAllPeers` | Same pipeline; `replaceAudioTrack` | Same branch |
| Mic/output device switch | New gUM → replaceTrack / `setSinkId` on elements | Same; output path untouched | Same branch |
| Background blur / camera switch | Canvas `captureStream()` → `localVideoStream` → `#syncVideoSenders` | Same processed track via `publishTrack` | `syncLocalVideo` |
| Video on/off + publisher cap | `/state` flag + controller cap | Identical flag + cap; camera grant in token per `video_allowed?` | `syncLocalVideo` |
| Screenshare + screen audio | Pre-negotiated 2nd transceiver; bare-track convention (~:2414) | `ScreenShare(+Audio)` sources; empty `streams` arg preserves the convention | Session only |
| `setWatching` receive gating | Publisher-side per-peer replaceTrack + bitrate ladder | Subscriber-side `setSubscribed` + explicit layer selection (§5) | `setVideoSubscriptionsEnabled` |
| Speaking indicators | `AudioMonitor` AnalyserNode on registry streams | Identical (LiveKit `ActiveSpeakersChanged` deliberately unused — one code path) | None |
| Per-participant volume/mute | Element `volume`/`muted` maps | Identical | None |
| Sound effects / autoplay recovery | Roster-diff driven | Identical (roster from MessageBus on both) | None |
| Idle/AFK/auto-status | IdleTracker + heartbeat piggyback | Identical | None |
| Stage rooms | Peering rules + `/state` unmute enforcement | Token `canPublish` + same `/state` enforcement; promotion → `UpdateParticipant` + `refreshPublications` | Role branch |
| Kick | `kicked` MessageBus → client leave | Same + best-effort `RemoveParticipant` | Server call |
| Reconnection | PeerManager restarts/backoff/ICE-restart | SDK resume → ladder (§7d) | Session |
| Multi-tab | Undefined-ish (mesh peers keyed by userId collide) | Deterministic: `DUPLICATE_IDENTITY` drops the older tab via **local-only** teardown. Documented improvement, unit-tested | Handler |
| Sessions/badges/co-presence/stats/user status | REST + jobs | **Identical — transport never touches them** | None |
| Anon directory viewing | MessageBus + serializers | Identical (anons never get tokens) | None |

## 9. Implementation phases (PR-sized, independently shippable)

Order: 1 → 2 → 3 strictly sequential; 4/5/6 parallelizable after 3; 7/8/9
last. Run `bin/lint --fix` on every change; JS tests run via CI.

**PR 1 — P2P-only seam tagging (zero behavior change).**
`voice-webrtc.js`: `#roomTransports`/`#isMeshRoom` defaulting mesh; guard
the peer-build block in `#handleParticipants`, the `signal` dispatch, and
`#handleRoleChange`'s rebuild; read `data.transport ?? "mesh"` in `join`.
`rooms_controller.rb`: join response gains `transport: "mesh"`.
*Acceptance*: entire existing JS suite (`voice-webrtc-test.js`,
`peer-manager-test.js`, `signaling-test.js`), integration `.gjs` tests, and
system specs pass **unmodified**; diff has no deletions of mesh logic.

**PR 2 — Server: settings, validator, resolver, tokens, pin.**
`settings.yml` + locales, `lib/validators/voice_livekit_policy_validator.rb`,
`lib/voice/livekit.rb`, pin helpers in
`app/services/voice/participant_tracker.rb`, `rooms_controller.rb`
(resolution, join payload, `livekit_token` with presence re-add + rate limit +
410 semantics, signal guard, pin-clear on last leave),
`Jobs::PublishRoomParticipants` backstop, `config/routes.rb`, `plugin.rb`
Site attr, request specs.
*Acceptance*: LiveKit unconfigured → join responses byte-identical plus
`transport: "mesh"`. Token decodes to the full §4 claim set across the
guardian × room_type × video matrix (stage listener → `canPublish: false`;
video-off room → no camera source; anon → no token path). Pin lifecycle spec:
set on first join (NX under race), held across config change, cleared on
empty, ~60 s expiry after crash, `livekit_token` works without presence and
410s when the pin is gone. Mint failure follows §7a/b including the
mesh-fallback setting. Secret never appears in any payload.

**PR 3 — Client: vendored SDK + LivekitRoomSession, audio-only calls.**
`scripts/build-livekit-bundle.sh`, checked-in bundle, package.json devDep,
`lib/voice/livekit-session.js`, `voice-webrtc.js` (join/connect path with
DELETE-/leave-on-failure, `#replaceTrackOnAllPeers` fan-out, leave/teardown +
`skipServer`, disconnect-reason handling, ghost-participant roster rule), unit
tests with a fake SDK injected via `loadSdk`.
*Acceptance*: mesh tests untouched and green. LiveKit unit tests prove: SDK
never loaded for mesh rooms (spy on `loadSdk`); mic published post-join; NS
toggle → `replaceAudioTrack`; `TrackSubscribed` populates
`remoteStreams`/`remoteStreamFor` with numeric userId keys; screen-audio
convention preserved; `DUPLICATE_IDENTITY` → local-only teardown **with no
DELETE /leave issued**; connect failure → DELETE /leave + join-failure path;
roster expulsion drops the participant's media; reconnect ladder stops on 410.
CI grep guard on static imports in place.

**PR 4 — Client: video, screenshare, watching, quality, role change.**
`livekit-session.js` (`syncLocalVideo`, `setVideoSubscriptionsEnabled` +
`TrackPublished` late-publication handling, subscriber layer selection,
publish encoding presets, `refreshPublications`), service branches
(`#syncVideoSenders`/`#broadcastVideoState`/`setWatching`/`#handleRoleChange`).
*Acceptance*: camera toggle publishes with simulcast + encoding preset and
POSTs `/state` identically to mesh; screenshare lands in
`remoteScreenAudioStreams`; `setWatching(false)` unsubscribes, and a camera
published afterwards starts unsubscribed until `setWatching(true)`; layer
selection: >6 publishers → LOW tiles, screenshare stays HIGH; role promotion
publishes mic without reconnect. Mesh video tests untouched.

**PR 5 — Server: moderation/lifecycle sync.**
`lib/voice/livekit/room_service_client.rb` (3 Twirp calls),
`rooms_controller#kick`/`#destroy`, `room_memberships_controller.rb`, "End
live call" admin action (per-user `publish_kick` loop + `delete_room` + pin
clear), `rake voice:clear_transport_pins`, WebMock specs.
*Acceptance*: kick/role change/destroy fire Twirp calls on livekit-pinned
rooms; LiveKit downtime never fails a Discourse request; mesh rooms make zero
HTTP calls; End-live-call empties a room using only existing client message
types.

**PR 6 — Per-room policy surface.**
Migration (load `.skills/discourse-migration` first), `room.rb`, serializer,
both param permit lists, `voice-room-form.gjs` FormKit checkbox gated on
`Site.voice_livekit_per_room_available`, locales.
*Acceptance*: checkbox visible only when configured + policy `per_room`;
toggling mid-call doesn't affect the live instance (pin precedence spec);
stale-form submit is accepted-but-inert when policy changed; mesh-only
installs see no form change.

**PR 7 — Real-LiveKit testing, docs, runbook.**
`spec/system/voice_livekit_spec.rb` (two-browser camera flow mirroring
`voice_voice_rooms_spec.rb`, gated on `ENV["VOICE_LIVEKIT_TEST_URL"]`,
docs show `docker run livekit/livekit-server --dev`); verify
`voice_fake_media.rb` fakes satisfy the SDK (expected no-op — livekit-client
uses `navigator.mediaDevices` and we publish our own tracks);
`docs/local-fake-participants.md`, `README.md`, `ARCHITECTURE.md` updates;
§10 runbook as an ops doc including CSP note; manual Safari + iOS/Android
checklist (join, hear audio, publish camera, receive screenshare, reconnect
after backgrounding — livekit-client has real platform nuances: H.264 vs VP8
simulcast on Safari, autoplay vs service-owned elements);
`isBrowserSupported()` guard wired to a translated toast; voice-bots README
PR in the external repo (WSS/UDP egress; the "≥2 bots per room" mesh
workaround does not apply to livekit rooms).
*Acceptance*: gated system spec green against a dev container locally;
ungated CI unchanged.

**PR 8 (optional) — Webhook reconciliation.** Controller + route + verifier +
specs per §4. *Acceptance*: signature/body-hash rejection paths;
`participant_left`/`participant_connection_aborted` early-expire stale
presence; `room_finished` clears the pin; `last_webhook_at` freshness marker;
no effect on Session rows beyond existing TTL behavior.

**PR 9 (optional) — Admin health panel.** Probe job, status endpoint,
dashboard card, `[voice-livekit]` log audit, secret-never-serialized spec,
per §4.

## 10. Enterprise deployment runbook (sketch — full version ships in PR 7)

1. Provision: 2–4 cores is ample (audio ≈ hundreds of participants/core,
   720p ≈ ~100 tracks/core). Run `livekit/livekit-server` (Docker or binary)
   with one `key: secret` API pair, `use_external_ip: true` behind NAT,
   `webhook.urls: [https://forum.example/voice/livekit/webhook]` if PR 8 is
   deployed. Single node — no Redis needed; each room must fit one node.
2. Network: reverse proxy (WebSocket upgrade + long timeouts) → 7880 as
   `wss://livekit.example.com`; open 7881/TCP (ICE-TCP fallback) and the UDP
   range; optionally embedded TURN on 443/TLS with its own hostname + cert.
   Classic failure: "connects but no media" = missing
   `use_external_ip`/firewalled UDP — check first. If a CSP is enforced at the
   proxy in front of **Discourse**, `connect-src` must include the LiveKit wss
   host (Discourse core currently emits no connect-src of its own — but see
   risk 8).
3. Discourse: set `voice_livekit_url` / `_api_key` / `_api_secret`; pick
   `voice_livekit_room_policy`. Mesh rooms keep using the existing
   STUN/TURN settings.
4. Verify: PR 9's status panel, or join a livekit room from two networks and
   confirm `transport: "livekit"` in the join response + a single PC to the
   SFU in `chrome://webrtc-internals`.
5. Operations: settings changes apply to the next room instance; force-flip a
   live room via "End live call" or `rake voice:clear_transport_pins`. If
   the SFU dies mid-call, clients run the reconnect ladder; presence/analytics
   keep working (heartbeats are Discourse-side).
6. Multisite / shared cluster: one API key pair per site; each site's webhook
   URL listed in the LiveKit config; room names are DB-prefixed by default as
   defense in depth.
7. Upgrades: the client SDK bundle is pinned in-repo (`build:livekit` bumps
   it); document the tested server version range in README.

## 11. Risks

1. **Vendored SDK ↔ server protocol drift** — pin + document the tested server
   range; bumps are one-commit affairs via the build script.
2. **`track.enabled` mute through SFU** — silence frames still consume (tiny,
   DTX-suppressed) upstream. Accepted for path parity; SFU-side `setMuted` is
   a later optimization behind the same seam.
3. **Watcher-gating semantics shift** — mesh gates at the publisher
   (non-watchers cost the publisher nothing); LiveKit publishes once
   regardless. Publisher upstream is constant (the point of an SFU), but the
   `voice_video_max_publishers` copy ("increases CPU for everyone") is wrong
   for livekit rooms — locale nuance in PR 7.
4. **Role-change permission race** — if `UpdateParticipant` fails and the
   client publishes before re-mint, the SFU rejects the publish. Mitigation:
   `refreshPublications` retries after `reconnectWithToken`; the `/state`
   unmute rule still gates the roster flag.
5. **`connectionStateFor` fidelity** — LiveKit `Reconnecting` doesn't surface
   as `"connecting"` (mesh doesn't surface per-peer trouble either — parity,
   not regression). Candidate follow-up.
6. **Pinned-livekit + broken config = room unjoinable by design** — never
   split a room; validator + runbook + explicit error copy mitigate.
7. **Multi-tab behavior changes on livekit** (older tab drops
   deterministically) — an improvement over mesh's undefined collision, but
   document it and keep the local-only-teardown unit test.
8. **Core CSP roadmap** — core plans to promote `connect_src` to an
   extendable default directive (`lib/content_security_policy/builder.rb`
   currently no-ops plugin connect_src extensions). When that lands, the
   plugin must register a CSP extension for the configured
   `voice_livekit_url` host or every LiveKit install breaks on a core
   upgrade. Track it; cheap now, expensive to discover later.

## 12. Open questions (product)

1. Should `all_rooms` also cover audio-only rooms while `voice_video_enabled`
   is off? Design says yes — audio-only is the cheapest LiveKit workload.
2. Adopt LiveKit `ActiveSpeakersChanged` for speaking indicators on livekit
   rooms eventually (saves N AudioContexts in large rooms)? Deferred — forks
   the indicator path.
3. Egress/HLS "broadcast stages" — confirm the room-name scheme now
   (`{db}-r{id}`) so egress can key off it later.
4. voice-bots at SFU scale: a lone bot *does* transmit to an SFU (the mesh
   "≥2 bots" workaround is obsolete there) — downsize bot rosters for livekit
   demo rooms?
