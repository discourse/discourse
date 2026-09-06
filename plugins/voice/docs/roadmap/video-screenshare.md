# Video & Screen Sharing

> **Revision note (2026-06-12):** this doc supersedes the original draft. Two
> core decisions changed after a deep read of the WebRTC layer:
>
> 1. **Media strategy** — the original plan relied on `addTrack()` +
>    `onnegotiationneeded` renegotiation. The codebase has _no_ renegotiation
>    path (no `onnegotiationneeded` handler; glare handling, the ufrag restart
>    heuristic, and answer-state guards all assume one-shot negotiation at peer
>    setup). The new design pre-allocates video transceivers at peer creation
>    and toggles video with `replaceTrack()` — zero renegotiation, matching the
>    pattern noise suppression already uses.
> 2. **UI** — a dedicated full-page room view (sidebar stays) replaces the
>    sliding video panel. Simpler, deep-linkable, and it doubles as the
>    subscription signal for who should receive video at all.
>
> Also new: a **per-room `video_enabled` toggle** and **subscription-gated
> sending**, which raises the practical mesh ceiling well above the original
> 3–5 stream estimate.

## Overview

Add optional camera video and screen sharing to voice rooms, staying **pure
full-mesh P2P** — no SFU, no media through the server. Joining a room remains
audio-first; video is something you opt into by opening the room's dedicated
page and turning on your camera.

Bandwidth is explicitly _not_ the constraint we design for (entry-level
broadband upload is now in the hundreds of Mbps). The binding constraints are:

- **CPU encoder sessions** — in a mesh, each `RTCPeerConnection` runs its own
  independent video encoder. A participant sending video to 8 watchers runs 8
  simultaneous encodes.
- **Decode + render cost** on the receiving side, especially mobile.

Both are attacked with the mesh topology's unique lever: every receiver has a
dedicated sender, so we can decide **per peer** whether to send video at all,
and at what resolution/bitrate. An SFU can't do better than simulcast here;
mesh gets per-link adaptation natively.

## Goals / non-goals

**Goals**

- Camera video and screen share in Open rooms, full mesh.
- Dedicated room page with a video grid; Discourse sidebar (and the rooms
  section in it) stays visible.
- Audio experience is never degraded or destabilized by the video feature.
- Per-room and site-wide opt-in.

**Non-goals (for now)**

- SFU integration (future, separate effort).
- Video in Stage rooms (speakers-only video is a follow-on).
- Recording, virtual backgrounds, reactions overlay.

## Facts about the current architecture that shape the design

From `voice-webrtc.js`, `peer-manager.js`, `signaling.js`:

- **Negotiation is one-shot.** Offers/answers happen at peer setup. Glare is
  resolved by user-ID ordering only during setup; answers in unexpected
  signaling states are dropped; a changed ICE ufrag means "peer restarted —
  tear down and rebuild" rather than "renegotiate".
- **Mid-call media changes never renegotiate.** Noise suppression swaps the
  outgoing audio track with `sender.replaceTrack()`
  (`#replaceTrackOnAllPeers`); role changes rebuild peers wholesale
  (`#reconnectAllPeers`).
- **The signal relay is payload-opaque.** SDP with video m-lines flows through
  `POST /voice/rooms/:id/signal` unchanged. No server work needed for media.
- **Presence metadata is a free-form per-participant hash** in Redis
  (`ParticipantTracker`), already carrying `is_muted` / `is_deafened` /
  `idle_state`, broadcast via `RoomBroadcaster.publish_participants`. Video
  flags slot straight in.
- **Call state lives in the `voice-webrtc` service**, independent of routes —
  which is why audio survives navigation today, and why a video _page_ can be
  a pure view over service state.

## Media plan: pre-allocated transceivers + `replaceTrack`

### Peer setup

At `PeerManager.create()`, alongside the existing audio `addTrack` calls, both
sides add a video transceiver:

```javascript
pc.addTransceiver("video", { direction: "sendrecv" });
```

The video m-line is negotiated **once**, in the same initial offer/answer that
already works. An idle negotiated video sender transmits nothing, so
audio-only rooms pay no bandwidth or CPU cost.

**Answerer alignment (JSEP gotcha).** Applying a remote offer only reuses
local transceivers created via `addTrack` — never ones from `addTransceiver`,
which are reserved for the local side's next offer. Left alone, the answerer
gets a fresh `recvonly` transceiver for the offered video m-line and its
pre-allocated transceiver is orphaned, so the answerer can receive video but
never send it (one-directional video, surfaced as "the offerer's camera works,
the answerer's doesn't"). Between `setRemoteDescription(offer)` and
`createAnswer()`, the answerer therefore flips the associated transceiver's
direction to `sendrecv` (the answer then carries it — still no renegotiation)
and migrates any camera track off the orphan. Audio is unaffected because
audio tracks go through `addTrack` and are reused per spec.

### Camera on/off

- **On:** acquire a _separate_ camera stream with its own
  `getUserMedia({ video: ... })` call — never re-acquire or touch the mic
  stream, so the noise-suppression chain is untouched — then
  `transceiver.sender.replaceTrack(cameraTrack)` on each peer that should
  receive video (see subscription gating below).
- **Off:** `replaceTrack(null)` everywhere, stop the camera track (releases
  the camera light), broadcast the state change.

No renegotiation, no new signaling messages, no glare risk, ever.

### Required fixes this surfaces

1. **Per-user stream registry.** `#registerRemoteStream` keeps one stream per
   user and _replaces_ it when a different stream arrives. With
   `addTransceiver`, the incoming video track has no associated stream
   (`event.streams` is empty), so the current `ontrack` fallback would create
   a video-only `MediaStream` that clobbers the user's audio entry. Fix:
   maintain one `MediaStream` per remote user and `addTrack()` incoming tracks
   into it (or store `{ audioStream, videoStream }` per user).
2. **Restart path must restore video.** `PeerManager.restart()` rebuilds the
   peer from `getLocalStream()`. Centralize an "attach current local media"
   step (audio tracks + video transceiver + current camera track if the peer
   is a subscriber) used by both `create()` and restart.
3. **UI must not key off `ontrack` for video.** The remote video track arrives
   muted at initial negotiation, long before any camera turns on. Drive tile
   visibility from the `is_video_on` presence flag (authoritative) plus the
   track's `mute`/`unmute` events (frame-accurate).

### Legacy peers

Connections negotiated before this ships have audio-only SDPs with no video
m-line. If a user enables camera against such a peer, fall back to the
existing sledgehammer: the `#reconnectAllPeers`-style rebuild that role
changes already use. Transitional code only.

## Subscription-gated sending (the mesh superpower)

Senders only attach the camera track toward peers who are **watching** — i.e.
currently on the room's video page. Everyone else's sender keeps a null track.

- Each non-watching peer skipped saves the sender an **entire encoder
  session**, not just bandwidth.
- The signal is free: entering/leaving the room page flips a `watching_video`
  flag in presence metadata, which already broadcasts to the room.
- Sidebar-only listeners (today's default UX) cost video senders nothing.

This is what raises the practical ceiling from the old "3–5 video streams" to
"~8 publishers, bounded by who is actually watching".

## Quality budget

Capture once at 720p; downscale per sender with
`sender.setParameters({ encodings: [{ maxBitrate, scaleResolutionDownBy, maxFramerate }] })`,
scaled by **watcher count**:

| Watchers | Per-peer encoding | Upload @ 8 watchers | Encodes |
| -------- | ----------------- | ------------------- | ------- |
| ≤ 3      | 720p @ ~1.2 Mbps  | —                   | ≤ 3     |
| 4–6      | 480p @ ~700 kbps  | ~3.5 Mbps           | 4–6     |
| 7+       | 360p @ ~400 kbps  | ~2.8 Mbps           | 7+      |

Plus:

- `track.contentHint = "motion"` (camera) / `"detail"` (screen share);
  `degradationPreference: "maintain-framerate"` for camera.
- Frame-rate caps: 24 fps, 15 fps in large rooms; screen share 15 fps.
- Mesh gives per-link adaptation for free: each `RTCPeerConnection`'s
  bandwidth estimator adapts to _that_ peer's downlink independently — one
  weak peer never degrades what others receive. (This is the mesh-native
  equivalent of simulcast; simulcast itself is an SFU mechanism and does not
  apply.)
- A user-selectable quality profile (High/Medium/Low, persisted in
  `localStorage`) remains useful as a manual override for weak _sending_
  hardware, layered under the automatic count-based ladder.
- `voice_video_max_publishers` (default 8) as the honest backstop: camera
  buttons disable past the cap, server rejects the flag. Audio mesh keeps
  scaling beyond it.

## UX: the room page

### Navigation

- Sidebar room rows gain an "open room" affordance (and/or clicking the room
  name while connected navigates; click-to-join on the join button is
  unchanged).
- Route: **`/voice/r/:slug`**. The engine already serves JSON at
  `/voice/rooms/:id`, so the page uses a distinct path. Server side: a route
  that renders the Ember app shell (core chat's full-page route is the
  reference pattern); client side: a plugin route map entry.
- The Discourse sidebar — including the Voice rooms section — persists
  automatically: the page renders in the regular content outlet.

```
┌──────────┬─────────────────────────────────┐
│ Sidebar  │  Room: Watercooler              │
│          │ ┌─────────┐ ┌─────────┐         │
│ 🎙 Rooms │ │ Alice 🎥 │ │  Bob 🎥 │        │
│  Water.. │ ├─────────┤ ├─────────┤         │
│  👤👤👤  │ │ Carol 👤 │ │ You 🎥  │        │
│  Lounge  │ └─────────┘ └─────────┘         │
│          │                                 │
│ (rest of │ [🎤] [🎧] [📷] [🖥️] [☎ leave]  │
│ sidebar) │                                 │
└──────────┴─────────────────────────────────┘
```

- **The page works for every room, video-enabled or not.** Participants
  without video render as avatar tiles with the existing speaking ring
  (reusing `AudioMonitor` state). This makes the page a general "room view",
  with video as an enhancement where allowed.
- Being on the page = `watching_video: true` in presence; navigating away
  flips it off and senders drop your video feed. Audio continues regardless
  (service state is route-independent).
- Layout: CSS grid, `auto-fit`/`minmax`, BEM classes
  (`.voice-room-page`, `.voice-video-tile`, modifiers like `--speaking`,
  `--screen-share`, `--self`).
- Active-speaker spotlight and click-to-pin: follow-on, not v1.

### Video tile anatomy (unchanged from original draft)

- `<video>` with `object-fit: cover` (camera) / `contain` (screen share).
- Bottom overlay: username, mute icon, camera/screen badge.
- Speaking indicator: border glow driven by existing speaking detection.
- Self view mirrored with `transform: scaleX(-1)` (camera only).
- Camera-off: avatar centered on dark background.
- Right-click: existing participant context menu (volume, mute, kick).

### Controls bar

Mic toggle, deafen, camera toggle, screen share, leave. Camera and screen
share buttons render only when video is effectively enabled for the room
(below) and disable with a tooltip when the publisher cap is reached.

### Sidebar indicators

- Camera icon next to participants with `is_video_on` in the room's expanded
  participant rows.
- A video badge on the room link itself when any participant is publishing,
  so browsers of the sidebar can see "there's video happening here".

## Per-room video toggle

Video has a different social temperature than audio; room owners should
control it.

- **Schema:** `video_enabled` boolean on `voice_rooms`, `null: false`,
  `default: true`.
- **Effective rule:**

  ```
  video allowed in room = SiteSetting.voice_video_enabled &&
                          room.video_enabled &&
                          room.open?            # stage rooms excluded in v1
  ```

- **Editing:** checkbox in the room create/edit form (FormKit), editable by
  whoever can manage the room (creator/managers — existing
  `can_manage_voice_room?` guardian); also exposed in the admin room UI.
  Permitted in `rooms_controller#room_params` and serialized in
  `RoomSerializer`.
- **Enforcement:** server-side in the state endpoint (below) — reject
  `is_video_on: true` / screen-share flags when video isn't allowed for the
  room, mirroring how `toggle_mute` rejects listener unmutes in stage rooms.
  Client hides the buttons; the server check is the real gate.
- **Flipping it off live:** broadcast the room update (directory broadcaster
  already pushes room CRUD); clients with active cameras stop sending
  (`replaceTrack(null)`) and toast.

## Server changes (small by design)

1. **Migration:** add `video_enabled` to `voice_rooms` (see above).
2. **Presence metadata keys:** `is_video_on`, `is_screen_sharing`,
   `watching_video` — same mechanism as `is_muted`/`is_deafened`.
3. **Endpoint:** generalize `toggle_mute` into (or add alongside it)
   `POST /voice/rooms/:id/state` accepting the metadata booleans, with the
   per-room enforcement above and the publisher-cap check
   (count of participants with `is_video_on` ≥ `voice_video_max_publishers`
   → 422).
4. **Site settings** (`config/settings.yml`):

   ```yaml
   voice_video_enabled:
     default: false
     client: true
   voice_video_max_publishers:
     default: 8
     min: 2
     max: 16
     client: true
   ```

   Off by default — admin opt-in, independent of voice.

5. **Page route** rendering the app shell at `/voice/r/:slug`, guarded by
   `ensure_can_join_voice_room!`-equivalent visibility (the room must be
   visible to the user; joining still requires the explicit join action).

Nothing changes in the signal relay.

## Screen sharing

Nearly free once camera works — it's the same transceiver machinery:

- `getDisplayMedia({ video: { frameRate: { max: 15 } } })`, then
  `replaceTrack` on the _same_ video transceiver.
- **Camera XOR screen** per user (one video track each way), as in the
  original draft — keeps transceiver count and UI simple.
- Handle the browser's native "Stop sharing" via `track.onended`.
- Hide the button where `getDisplayMedia` is unavailable (iOS Safari, most
  Android browsers).
- Screen tiles: `object-fit: contain`, no mirror, "Screen" badge; a screen
  share auto-pins as the spotlight tile once spotlight exists.

## Phasing

1. **Foundation (no UI to speak of).** Video transceivers at peer setup,
   separate camera stream, `replaceTrack` camera toggle (temporary debug
   button), per-user stream registry fix, restart-path media reattachment,
   `is_video_on` presence flag, site settings. Behind
   `voice_video_enabled`; audio path untouched.
2. **The page.** `/voice/r/:slug` route, tile grid (avatar tiles for all
   rooms, video tiles where allowed), controls bar, sidebar indicators,
   per-room `video_enabled` toggle + form + enforcement.
3. **Boundary pushing.** `watching_video` subscription gating, watcher-count
   bitrate/resolution ladder, publisher cap enforcement, quality profile
   override, mobile tile limits.
4. **Screen share + spotlight.** `getDisplayMedia`, camera XOR screen,
   active-speaker/pin spotlight layout.

## Edge cases

- **Camera enable at publisher cap:** button disabled with tooltip; server
  422s as the real gate (client count can be stale).
- **Two users enable camera simultaneously:** no interaction at all —
  `replaceTrack` involves no signaling, so there is nothing to glare. (The
  original draft's renegotiation-storm concern dissolves with this design.)
- **User joins mid-video:** initial negotiation includes the video m-line;
  watchers receive frames as soon as publishers' senders pick them up from
  the `watching_video` broadcast. No renegotiation.
- **Peer connection restart while camera on:** restart path reattaches the
  camera track for subscribed peers (required fix #2).
- **Room's `video_enabled` switched off mid-call:** publishers stop sending,
  toast shown, tiles fall back to avatars.
- **Mobile:** camera works; cap rendered tiles on small viewports (decode
  cost), prefer the spotlight layout; backgrounding the browser stops the
  camera — broadcast `is_video_on: false` on track end.
- **PTT + video:** independent — PTT drives audio track `enabled`, video is a
  separate track.
- **Stage rooms:** excluded in v1 (`room.open?` in the effective rule).
  Follow-on: speakers may publish, listeners are watch-only — falls out of
  existing role logic since listeners already have no send path.
- **Deafened users:** deafen is audio-only; they still see video. (Matches
  Discord semantics.)

## Future enhancements (out of scope)

- Video in Stage rooms (speakers publish, listeners watch).
- SFU integration for rooms beyond mesh limits.
- Picture-in-picture via the native PiP API (supersedes the original draft's
  `window.open` popout idea — far less machinery for the same need).
- Active-speaker auto-spotlight, click-to-pin (phase 4 starts this).
- Virtual backgrounds (segmentation model, WebGL) — note the DTLN worklet
  already establishes the WASM-in-media-pipeline pattern.
- Recording, reactions overlay.
