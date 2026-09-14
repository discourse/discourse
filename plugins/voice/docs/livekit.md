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
else for human participants (presence, sessions, badges, admin stats, the roster UI, mute/deafen,
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

## Recording to S3 with LiveKit Cloud

LiveKit Cloud runs the recorder, but each recording request must specify
where to store the file. Voice supports a dedicated S3 bucket using the
settings below. These settings are independent of Discourse's upload and
backup storage configuration.

1. Create an S3 bucket for recordings and credentials with permission to
   write objects under the recording prefix. Keep the bucket private unless
   you intentionally want anyone with a recording URL to be able to read it.
2. Configure `voice_livekit_url` with the project's `wss://` URL and set its
   API key and secret.
3. In Discourse site settings, configure these values, saving the bucket
   last:

   | Setting | Value |
   | --- | --- |
   | `voice_livekit_recording_s3_region` | The recording bucket's AWS region |
   | `voice_livekit_recording_s3_access_key_id` | Dedicated recording access key |
   | `voice_livekit_recording_s3_secret_access_key` | Dedicated recording secret key |
   | `voice_livekit_recording_s3_endpoint` | Leave empty for AWS S3; an HTTPS origin for S3-compatible storage |
   | `voice_livekit_recording_s3_bucket` | Bucket name only, without a folder prefix |
   | `voice_livekit_recording_filepath` | Object key template, default `voice/{room_name}-{utc}` |

4. Enable `voice_livekit_recording_enabled` and start a recording in a
   LiveKit-routed room. Egress adds the file extension and Voice adds a random
   suffix to the object key.

The recording credentials are sent to the configured LiveKit server over
HTTPS with each start request. No S3 credentials are sent to participants.
The endpoint option uses path-style addressing for S3-compatible providers.

When recording finishes, Voice sends the requester a PM with the location
returned by LiveKit. **This is not a signed download URL.** For private
buckets, an operator must retrieve the file using authenticated S3 access;
the PM link alone does not grant access. Discourse secure-upload rules do
not apply to these external recordings.

An empty recording bucket preserves self-hosted Egress storage configuration.
On LiveKit Cloud, a filepath without a storage destination can fail with
`request has missing or invalid field: output`. Configure the dedicated S3
settings to resolve this error; changing the filepath alone does not help.

See [LiveKit's output and storage documentation](https://docs.livekit.io/transport/media/ingress-egress/egress/outputs/).

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

For human participants, webhooks never *create* presence and never touch session
analytics — those ride Discourse heartbeats on both transports. If webhooks are undelivered
(firewall, misconfigured URL), nothing breaks; the built-in TTLs just take a
little longer to converge, so treat a stale delivery marker as a warning,
never an outage.

Authorized external agents have a separate lifecycle: provider connection events
and reconciliation maintain their presence, while Discourse controls admission,
invitations and removal. They do not create human session analytics. See
[External agent participation](./roadmap/agent-participation.md) for the contract
and its implementation checklist.

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

## LiveKit Agent Builder

Voice supports manually inviting a chosen LiveKit Cloud agent into ongoing
public Voice calls. Deploy the agent with Agent Builder in the same Cloud project
configured for Voice. The agent does not need `VOICE_AGENT_CREDENTIAL` or a
Discourse HTTP tool.

### Setup and testing

1. In **Admin → Settings**, enable `voice_livekit_agent_enabled`. This creates the
   `livekit_agent_bot` account automatically. Voice uses its existing LiveKit URL
   and API credentials.
2. Make a public Voice room use LiveKit through the existing room policy. Join it
   as a human and confirm that the call uses LiveKit. Mesh calls cannot invite an
   agent and do not switch transport automatically.
3. As an admin, open the room's **…** menu (on its page or in the sidebar) and
   select **Invite LiveKit agent**. The same action is available in the widget’s
   **…** menu. Enter the deployed agent’s dispatch name in the modal and invite it.
   Choose a name for each invitation; do not use its `CA_` deployment ID.
4. Wait for `livekit_agent_bot` to appear, then speak. With webhooks configured,
   presence can appear promptly; otherwise allow the next one-minute scheduled
   sweep. The agent's initial greeting may occur before roster admission.
5. Open the bot's participant menu and select **Kick**. Verify that its roster
   entry and audio disappear. Invite it again immediately from the room menu.
   Each invitation creates a fresh session; no expulsion duration is stored.
6. Leave as the last human and verify the bot disconnects. Repeat after closing
   the human browser abruptly, allowing presence expiry and reconciliation.
7. Disable the feature while the bot is present and verify that it is removed.
   Enabling again reuses the same bot account. Private rooms, empty calls, non-admins, and a missing
   or inactive bot cannot initiate an invitation.

Set the LiveKit webhook URL to the site's public HTTPS origin followed by
`/voice/livekit/webhook`. Keep scheduled jobs running even
when webhooks are configured so missed events and cleanup failures are retried.

Agents always join as speakers. They do not count toward human capacity,
attendance, badges, or participation statistics. Room managers can kick them;
only admins can invite them. Nothing automatically dispatches an agent when
humans join a room.

### Hosting and provider behavior

The LiveKit Agents framework and dispatch mechanism support both Cloud and
self-hosted servers. Agent Builder and managed agent hosting are Cloud services.
This UI intentionally supports only a configured `wss://*.livekit.cloud` project.
See [LiveKit Cloud](https://docs.livekit.io/intro/cloud/) and
[Agent Builder](https://docs.livekit.io/agents/start/builder/).

An accepted invitation means LiveKit accepted the dispatch, not that a worker has
connected. Check LiveKit's session logs if the bot does not appear, particularly
the dispatch name and deployment status. Discourse associates the bot only with
the running job's identity returned by LiveKit's authenticated dispatch API;
participant metadata or matching display names cannot authorize roster access.

LiveKit controls a managed agent's initial connection permissions. Discourse
updates them before roster admission, disabling data publishing and applying the
room's permitted media sources. Use trusted agents: roster gating does not block
provider access before reconciliation. This flow supports audio conversation;
it does not enable Agent Console transcription or data features.

Cleanup records outlive revoked admission proofs, allowing failed deletion and
ambiguous dispatch creation responses to be reconciled. Discourse clients stop
agent playback on roster removal. Provider disconnection may lag during outages.
See the [dispatch API](https://docs.livekit.io/reference/agents/agent-dispatch-service-api/)
and [implementation contract](./roadmap/agent-participation.md).

Automated checks:

```bash
LOAD_PLUGINS=1 bin/rspec plugins/voice/spec --exclude-pattern 'plugins/voice/spec/system/**/*_spec.rb'
CI=1 bin/qunit --standalone --target voice --filter '/VoiceInviteAgentButton|VoiceParticipantSidebarContextMenu|voice-webrtc-livekit/i'
```

The real-SFU system spec above tests human media. A real dashboard-agent
conversation still requires the manual checks in this section.

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
