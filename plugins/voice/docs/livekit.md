# LiveKit media server (SFU) — deployment and operations

By default Voice runs calls as a pure peer-to-peer mesh: every participant
sends media to every other participant, and nothing touches the Discourse
server. That is the right default for small rooms and zero-infrastructure
installs, but upstream bandwidth grows with room size, so large rooms and
many simultaneous video publishers eventually hit browser and network limits.

Sites that need bigger calls can deploy their own [LiveKit](https://livekit.io)
server and point the plugin at it. Rooms routed through LiveKit publish each
track **once** to the SFU, which fans it out to subscribers — publisher
upstream stays constant no matter how many people are in the room. Everything
else (presence, sessions, badges, admin stats, the roster UI, mute/deafen,
push-to-talk, noise suppression, background blur) works identically on both
transports.

This document is the operations guide: provisioning, network setup, Discourse
configuration, verification, and day-2 operations. For the design itself see
[roadmap/livekit-sfu.md](./roadmap/livekit-sfu.md).

## How rooms pick a transport

- The **server** decides the transport when the first participant joins, and
  pins it (in Redis) for the life of that call. Everyone in a call is always
  on the same transport; there is no mixed room and no client-side choice.
- `voice_livekit_room_policy` controls the resolution: `disabled` (default,
  everything mesh), `per_room` (rooms opt in individually via a room-form
  checkbox), or `all_rooms`.
- **Setting changes never affect a call already in progress.** A room switches
  transport when its next call starts — i.e. after it empties. To force the
  issue, see [Emergency levers](#emergency-levers).

## Provisioning a LiveKit server

A modest VM goes a long way: 2–4 cores is ample for most communities (audio
is roughly hundreds of participants per core; 720p video roughly ~100 tracks
per core). Run the open-source `livekit/livekit-server` (Docker or a single
Go binary) with:

- one `key: secret` API pair (generate with `livekit-server generate-keys`),
- `use_external_ip: true` when the server sits behind NAT (cloud VMs almost
  always do),
- a single node — no Redis required; each room just has to fit on one node,
- optionally, [webhook delivery](#webhook-reconciliation-optional) back to the
  forum:

  ```yaml
  webhook:
    api_key: <the same API key>
    urls:
      - https://forum.example/voice/livekit/webhook
  ```

## Network setup

1. Put a reverse proxy (WebSocket upgrade + long timeouts) in front of
   LiveKit's HTTP/signal port 7880, exposed as `wss://livekit.example.com`.
2. Open **7881/TCP** (ICE over TCP fallback) and the **UDP port range**
   (default 50000–60000, configurable) directly to the LiveKit host — media
   does not go through the reverse proxy.
3. Optionally enable LiveKit's embedded TURN on 443/TLS with its own hostname
   and certificate for clients on networks that block everything else.

**The classic failure is "connects but no media"**: signaling over wss works
through the proxy, but RTP can't flow. Check `use_external_ip` and the UDP
range/firewall first — this is almost always the cause.

### Content Security Policy

Browsers connect to the LiveKit host with WebSocket. Discourse core currently
emits no `connect-src` directive of its own, so a stock install needs nothing.
But if a CSP with `connect-src` is enforced by a proxy in front of
**Discourse**, it must include the LiveKit wss host, or every join fails with
a CSP violation in the console. (If core ever starts emitting `connect-src`
by default, the plugin will need to register a CSP extension for the
configured host — tracked as a known risk in the roadmap.)

## Discourse configuration

| Setting | Value |
| --- | --- |
| `voice_livekit_url` | `wss://livekit.example.com` (or `ws://` for plain-HTTP labs) |
| `voice_livekit_api_key` | the API key |
| `voice_livekit_api_secret` | the API secret |
| `voice_livekit_room_policy` | `per_room` or `all_rooms` |
| `voice_livekit_room_prefix` | optional room-name namespace; defaults to the site's database name |
| `voice_livekit_mesh_fallback` | opt-in: when a token can't be minted and the room is empty, start on mesh instead of failing the join. Off by default — silent degradation hides outages |

The policy setting validates that URL, key, and secret are present before it
can leave `disabled`, so misconfiguration fails at save time, not at a user's
first join. None of these settings are sent to clients; the URL and a
short-lived (10 minute), single-room, single-user token reach the browser only
in the join response of rooms actually resolved to LiveKit.

Mesh rooms keep using the existing `voice_stun_servers` /
`voice_turn_servers` settings; LiveKit brings its own ICE/TURN and ignores
them.

With `per_room` policy, room creators/managers get a "Use media server (SFU)"
checkbox in the room form. Toggling it affects the room's next call, never a
live one.

## Verifying a deployment

1. Join a LiveKit-routed room from two different networks and confirm you can
   hear each other and see cameras.
2. In `chrome://webrtc-internals`, a LiveKit call shows a **single**
   PeerConnection to the SFU host (a mesh call shows one per participant).
3. The join response (`POST /voice/rooms/:id/join` in devtools) carries
   `"transport": "livekit"`.
4. For an automated end-to-end check from a dev machine, see
   [Local testing](#local-testing-and-the-gated-system-spec).

If joins fail with "Voice server unavailable", the server rejected the token
mint (bad key/secret or half-deleted config) — check `/logs` for entries
prefixed `[voice-livekit]`. If joins fail with "Your network cannot reach
the voice server", minting worked but the **client** couldn't reach the SFU
(corporate firewall blocking WSS/UDP is the usual suspect) — this is
deliberately never fallen back to mesh, because other participants may reach
the SFU fine and a room must never split across transports.

## Operations

- **Settings changes** (URL, keys, policy) apply to each room's next call.
  Live calls keep their pinned transport until the room empties.
- **Ending a live call**: admins can end any room's call from
  **Admin → Plugins → Voice** (the room list's "End call" action). It kicks
  every participant, deletes the LiveKit room, and clears the transport pin,
  so the next join re-resolves against current settings.
- **Emergency levers**:
  - `rake voice:clear_transport_pins` drops every pinned transport at once
    (rooms re-resolve on their next join; occupants of a live call are not
    disconnected, so prefer "End call" for occupied rooms).
  - Setting the policy back to `disabled` stops new LiveKit calls immediately;
    live ones finish on LiveKit.
- **SFU outage mid-call**: clients ride out brief blips via the SDK's
  auto-resume; on a hard disconnect they retry three times with fresh tokens,
  then leave with a toast. Presence, sessions, and stats are unaffected
  throughout — they ride Discourse heartbeats, not media.
- **Kicks, role changes, room deletion** are synced to LiveKit best-effort;
  LiveKit being down never fails a Discourse request (the client-side
  enforcement still applies either way).

## Webhook reconciliation (optional)

With `webhook.urls` configured on the LiveKit server (see
[Provisioning](#provisioning-a-livekit-server)), the plugin accepts signed
webhook deliveries at `POST /voice/livekit/webhook` and uses them as a
**reconcile-only backstop**:

- `participant_left` / `participant_connection_aborted` expire the
  participant's presence early, so someone whose connection died drops off the
  roster in seconds instead of waiting out the heartbeat TTL.
- `room_finished` clears the room's transport pin, so the next call
  re-resolves against current settings right away.

Webhooks never *create* presence and never touch session analytics — those
ride Discourse heartbeats on both transports. If webhooks are undelivered
(firewall, misconfigured URL), nothing breaks; the built-in TTLs just take a
little longer to converge, so treat a stale delivery marker as a warning,
never an outage.

Deliveries are authenticated by the `Authorization` JWT LiveKit signs with the
API secret, which includes a hash of the request body — no extra shared
secret to configure. Rejected deliveries are logged to `/logs` prefixed
`[voice-livekit]`.

## Multisite / shared clusters

- Use one API key pair per site.
- Room names are namespaced with the site's database name by default
  (`{db}-r{room_id}`), so sites on a shared LiveKit server can't collide;
  `voice_livekit_room_prefix` overrides the prefix.
- Webhooks are a partial fit here: LiveKit signs every delivery with the
  single `webhook.api_key`, so with per-site key pairs only the site owning
  that key can verify deliveries — the others safely reject them (403) and
  fall back to the heartbeat TTLs. Sites that do verify still ignore events
  for rooms outside their own name prefix.

## Upgrades

The client SDK is a pinned `livekit-client` bundle vendored in this repo
(`livekit/livekit-client.js`, shipped in the discourse_voice_assets gem and
rebuilt via its `scripts/build-livekit-bundle.sh`). Server upgrades within the same major
version are safe; when bumping the vendored SDK, re-run the gated system spec
below and the manual checklist against the server version you deploy.

## Local testing and the gated system spec

Run a disposable dev server (API key `devkey`, secret `secret`):

```bash
docker run --rm -p 7880:7880 livekit/livekit-server --dev
```

Then run the real-LiveKit system spec, which is skipped unless the URL is
present:

```bash
VOICE_LIVEKIT_TEST_URL=ws://localhost:7880 \
  bin/rspec plugins/voice/spec/system/voice_livekit_spec.rb
```

(When running on a dev machine add `CI=1`: outside CI, core pins every test
browser to one fixed remote-debugging port, which breaks any system spec —
this one included — that opens a second browser session.)

It drives a two-browser camera call through the SFU using the same fake-media
harness as the mesh specs — which also proves the fakes satisfy the LiveKit
SDK (the plugin acquires media itself and hands the SDK finished tracks; the
SDK never calls `getUserMedia`).

The [local fake participants harness](./local-fake-participants.md) works
against LiveKit-routed rooms unchanged, for the same reason.

## Manual browser checklist

`livekit-client` has real platform nuances the automated Chromium-only spec
can't see (H.264 vs VP8 simulcast on Safari, autoplay policies against the
plugin's service-owned media elements, mobile backgrounding). When bumping
the vendored SDK or the server version, walk this list on **macOS Safari,
iOS Safari, and Android Chrome** against a LiveKit-routed room:

- [ ] Join the room; the roster shows you and speaking indicators track your mic.
- [ ] Hear another participant's audio without tapping anything extra
      (autoplay recovery may show its "click to enable audio" prompt once —
      that's the existing, expected behavior).
- [ ] Publish your camera; a second participant sees it.
- [ ] Receive a screenshare (with its audio, when shared from a desktop
      browser that supports tab audio).
- [ ] Mute/unmute and push-to-talk still register on the other side.
- [ ] Background the app (mobile) or sleep the laptop for ~30 s, come back:
      the call reconnects on its own, or lands you back in the room after the
      rejoin toast.
- [ ] Join the same room from a second tab/device as the same user: the older
      tab drops with the "continued in another tab" toast and the roster stays
      correct.
