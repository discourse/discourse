# Experimental Windows hardware mesh screen sharing

## Status

Proposed implementation plan. The feature remains disabled by default and is
limited initially to Windows 11 systems with a supported NVIDIA GPU.

## Objective

Publish a game or display at up to 3840×2160 and 60 frames per second, with
game or system audio, while encoding each quality layer only once in NVENC.
Mesh rooms continue to send media directly between participants; Discourse
only handles authorization, presence, and signaling.

The initial implementation runs beside the existing Flutter/libwebrtc call:

```text
Primary call (unchanged)              Experimental screen publisher
Flutter + libwebrtc                   Rust + webrtc-rs
├── microphone                        ├── Windows Graphics Capture
├── camera                            ├── D3D11 color conversion
├── incoming media                    ├── one NVENC H.264 encoder
└── primary peer connections          ├── WASAPI loopback + Opus
                                      └── one screen peer connection per viewer
```

Captured frames and encoded H.264 access units are shared. RTP state,
retransmission, congestion control, DTLS/SRTP, and ICE remain independent for
each viewer.

## Non-goals for the first release

- AMD or Intel hardware encoding.
- Windows versions earlier than Windows 11.
- Linux or macOS changes.
- Replacing the existing microphone, camera, receive, or rendering paths.
- Game-process injection or capture hooks that may conflict with anti-cheat
  software.
- Silent fallback to software encoding.
- Unlimited viewer counts or independent per-viewer quality adaptation.
- LiveKit publishing through the Rust engine.

## Success criteria

On a supported Windows 11 and NVIDIA test system:

- A game or display can be shared at 3840×2160 and 60 fps.
- NVIDIA Video Encode utilization confirms that NVENC is active.
- The publisher does not perform a CPU pixel readback in the steady-state
  capture and encode path.
- Adding viewers does not add encoder sessions for the same quality layer.
- Game-process or system audio remains synchronized with video.
- One slow viewer cannot stall capture or delivery to other viewers.
- Voice and camera remain usable through the existing primary connection.
- Unsupported systems fail closed with an actionable explanation.
- Disabling the experiment restores the existing screen-sharing behavior.

Initial performance targets should be measured rather than treated as release
guarantees:

- 95th-percentile capture-to-encoded-frame latency below 25 ms.
- No sustained capture queue growth.
- Less than 10% aggregate CPU use attributable to capture and publishing on
  the reference system.
- Audio/video drift remains within 50 ms during a 30-minute session.

## Architecture

### Capture and encoding

Use Windows Graphics Capture (WGC) as the default source for windows and
displays. Keep DXGI Desktop Duplication as a later fallback for display or
exclusive-fullscreen cases that WGC cannot capture reliably.

```text
WGC frame pool
  → ID3D11Texture2D (BGRA)
  → GPU conversion and SDR/tone-map stage (NV12)
  → registered D3D11 NVENC input resource
  → H.264 Annex-B access unit
  → reference-counted broadcast ring
```

The first encoder profile is:

- H.264 with WebRTC-compatible profile and `packetization-mode=1`.
- 3840×2160 at 60 fps when the source and GPU sustain it.
- Low-latency tuning with no B-frames.
- Repeat SPS/PPS on IDR frames.
- Monotonic 90 kHz video timestamps.
- Configurable bitrate with a provisional 25–40 Mbps range for 4K60.
- Explicit force-IDR operation for consolidated PLI/FIR requests.

HDR sources must either stay in an HDR-capable pipeline end to end or pass
through an explicit GPU tone-mapping stage. The experiment should initially
declare SDR output and test HDR desktops for correct conversion rather than
allowing washed-out or clipped output.

Direct NVIDIA Video Codec SDK integration is the intended production path.
An FFmpeg `ddagrab`/`h264_nvenc` spike is acceptable for validating transport
and performance, but it must not become an accidental permanent dependency.
Any FFmpeg distribution requires a separate LGPL/GPL configuration and
redistribution review.

### Audio

Use WASAPI process-loopback capture for game audio when the user selects a
process. Include the process tree so child processes are captured. Offer
endpoint-wide system loopback as a distinct option with a clear label.

Audio is captured once, resampled to the Opus input format, encoded once, and
fanned out to per-peer audio tracks. Use QPC-derived timestamps and bounded
resampler correction to keep the audio clock aligned with the video clock.
Microphone audio remains on the primary Flutter/libwebrtc connection.

### Encoded-frame fan-out

Current webrtc-rs tracks bind to one peer connection. Create one local video
track and one local screen-audio track per viewer, and feed them from shared
broadcast sources:

```text
Arc<EncodedVideoAccessUnit>
  ├── bounded queue → peer A video track
  ├── bounded queue → peer B video track
  └── bounded queue → peer C video track

Arc<EncodedOpusFrame>
  ├── bounded queue → peer A audio track
  ├── bounded queue → peer B audio track
  └── bounded queue → peer C audio track
```

Packetization can occur per peer. Its cost is small compared with 4K encoding
and it preserves peer-specific SSRCs, payload types, header extensions, and
timestamps. A later optimization may packetize once and copy immutable RTP
payloads while rewriting peer-specific headers.

Never await all peer writes in the capture loop. Each peer has a bounded queue
and worker. A congested peer drops complete non-keyframe access units rather
than accumulating unbounded latency or blocking other peers.

NACK/RTX caches, receiver reports, TWCC/GCC, pacing, and SRTP remain per peer.
Only PLI/FIR requests are consolidated: debounce concurrent requests and ask
NVENC for one IDR that is delivered to every viewer.

### Quality adaptation

The first version publishes one shared quality layer. All viewers therefore
need enough downstream bandwidth for the configured stream. Apply both:

- a small experimental viewer cap; and
- per-peer overload detection that warns, sheds, or disconnects a viewer whose
  queue repeatedly overflows.

Do not globally lower quality to the weakest viewer without an explicit user
choice.

The next iteration can use a shared H.264 simulcast ladder, for example:

| Layer | Target | Provisional bitrate |
| --- | --- | --- |
| High | 2160p60 | 25–40 Mbps |
| Medium | 1080p60 | 8–12 Mbps |
| Low | 720p30 | 2–4 Mbps |

Each layer is encoded once and selected independently for each peer. Encoder
work becomes proportional to the number of layers, not the number of viewers.
The implementation must check the GPU's concurrent NVENC session capability
before enabling multiple layers.

Mesh upload bandwidth still scales with viewers. A 30 Mbps layer sent to four
viewers requires approximately 120 Mbps of publisher upload before protocol
overhead.

## Signaling protocol

The existing protocol assumes one peer connection per pair of users. Add a
bounded connection discriminator while preserving the current behavior:

```json
{
  "recipient_id": 123,
  "connection_id": "screen",
  "events": [
    { "type": "offer", "sdp": "..." }
  ]
}
```

Allowed values initially are:

- `primary`: existing voice/camera connection and the default when omitted.
- `screen`: experimental screen video and audio connection.

The server validates the value, groups batches by both recipient and
connection ID, and preserves it in the MessageBus envelope. The discriminator
must not be embedded in SDP or accepted as an arbitrary string.

Advertise a `mesh_screen_connection_v1` capability in the native participant
session metadata. The publisher creates secondary offers only for peers that
advertise this capability. This is mandatory: an old client must never route a
screen offer into its primary connection merely because it ignores an unknown
field.

For screen connections, the publisher always creates the offer and the viewer
answers. This avoids glare because the connection has one publisher. Closing
the secondary peer connections stops the share in the first version; inactive
transceivers and secondary-connection reuse can be considered later.

The existing room state update remains the source of truth for the visible
`screen: true` participant state.

## Native boundary

Expose a narrow asynchronous interface from a Windows Rust library to Flutter.
The exact bridge can use a C ABI with Dart FFI or generated bindings, but the
application-facing contract should remain owned by discourse-native:

```text
probeCapability() -> capability details or unsupported reason
listCaptureSources() -> windows and displays
startShare(config, iceConfig, participantSession)
addViewer(viewer, remoteCapability)
handleSignal(viewerId, event)
removeViewer(viewerId)
stopShare()
subscribeEvents() -> signal, state, stats, warning, failure
```

Do not expose NVIDIA, webrtc-rs, or raw FFI types to the Dart application.
Events need correlation IDs and redacted diagnostics consistent with the
existing Voice diagnostic capture.

The capability result must verify all of the following:

- Windows 11 is supported.
- The selected capture and encode adapters are compatible.
- An NVIDIA driver and NVENC H.264 session can be created.
- The requested resolution, frame rate, and concurrent-session count are
  supported.
- Process-loopback audio is available when requested.

If any check fails, the experimental path is unavailable. It must not silently
fall back to software encoding while presenting itself as hardware sharing.

## Rollout controls

Add a client-visible, default-off plugin site setting:

```text
voice_windows_hardware_screen_share_enabled
```

It only allows the client to attempt the feature. The client must additionally
pass the local runtime capability probe. A local runtime or build flag should
also be able to disable the experiment independently for emergency rollback.

The screen-share UI should label this path experimental, display the active
encoder, capture resolution, frame rate, and estimated upload requirement, and
allow falling back to existing screen sharing only through an explicit user
choice.

Start with an administrator/tester audience and a conservative viewer cap.
Expand only after telemetry demonstrates stable capture, A/V sync, driver
recovery, and network behavior.

## Implementation milestones

### 0. Windows build foundation

- Create the generated Flutter Windows runner using the repository's documented
  `flutter create` workflow.
- Establish a Windows CI build with Visual Studio 2022 and the pinned Flutter
  SDK.
- Package and load a minimal Rust DLL from the Windows runner.
- Add a deterministic Rust toolchain and dependency lock policy.
- Confirm application signing and redistribution requirements.

Exit: a Windows debug/release application loads a versioned Rust library and
passes a bridge smoke test in CI and on Windows 11.

### 1. Secondary-connection protocol

- Add the default-off site setting and server translation.
- Extend the signal validator, relay, and batching with `connection_id`.
- Add `mesh_screen_connection_v1` capability negotiation.
- Route `primary` signals exactly as before.
- Add fake secondary screen transports to the web and native clients.
- Implement lifecycle handling for roster changes, leave, kick, reconnect,
  room destruction, and participant-session replacement.

Exit: two capable clients establish and tear down a fake secondary connection
without affecting primary voice; old clients never receive secondary offers.

### 2. Rust WebRTC transport

- Create one webrtc-rs peer connection per capable viewer.
- Consume Voice ICE/TURN configuration.
- Implement publisher-offers/viewer-answers signaling.
- Publish synthetic H.264 and Opus fixtures.
- Implement bounded per-peer queues and independent transport workers.
- Surface connection state, RTCP keyframe requests, and stats through the
  native boundary.

Exit: a synthetic encoded stream reaches multiple browser viewers through
direct ICE and TURN, with only one shared input stream.

### 3. Windows capture and NVENC

- Enumerate WGC window and display sources.
- Capture D3D11 textures without CPU readback.
- Convert BGRA/HDR inputs to NV12 SDR on the GPU.
- Integrate NVENC H.264 low-latency encoding.
- Fan out immutable access units to every viewer track.
- Coalesce PLI/FIR and force IDR.
- Handle resize, source closure, adapter/device loss, sleep, and driver reset.

Exit: 4K60 video reaches multiple viewers while one NVENC session is active.

### 4. Game and system audio

- Add process-tree and endpoint-wide WASAPI loopback modes.
- Encode one Opus stream and fan it out to viewer audio tracks.
- Align QPC-derived audio and video timestamps.
- Add bounded drift correction and discontinuity recovery.
- Ensure stopping capture releases every COM, WASAPI, D3D11, and NVENC
  resource.

Exit: a 30-minute game share maintains the A/V drift target across multiple
viewers.

### 5. Hardening and experimental release

- Add capability and failure UX.
- Add redacted diagnostics and performance telemetry.
- Test direct, STUN, TURN/UDP, TURN/TCP, and TURN/TLS paths.
- Exercise packet loss, reordering, bandwidth collapse, and a slow viewer.
- Test source resize, alt-tab, minimization, HDR desktop, GPU reset, sleep,
  network changes, and participant churn.
- Complete dependency, NVIDIA SDK, codec/patent, and FFmpeg licensing review.
- Document the feature, limitations, expected upload, and rollback procedure.

Exit: the feature can be enabled for a limited audience and disabled without a
client release or impact to ordinary calls.

### 6. Shared simulcast

- Add two or three shared encoder layers.
- Select layers using each peer's congestion and receiver feedback.
- Switch at keyframe boundaries without recreating the call.
- Enforce GPU encoder-session capability and thermal/load limits.

Exit: heterogeneous viewers receive sustainable layers while encoder sessions
remain proportional to the configured layer count.

## Test strategy

### Plugin tests

- Reject unknown or malformed connection IDs.
- Preserve the default `primary` behavior when the field is absent.
- Keep batches for the same recipient but different connections separate.
- Preserve the discriminator through the relay.
- Enforce participant session, room permission, stage-role, rate-limit, and
  LiveKit/mesh policy checks for secondary connections.
- Never advertise or use the capability when the setting is disabled.

### Dart and JavaScript tests

- Route primary and screen signals to independent transports.
- Gate offers on both the site setting and peer capability.
- Restore the primary call when secondary setup or capture fails.
- Tear down screen connections on stop, track end, roster removal, kick,
  reconnect, account removal, and room destruction.
- Keep participant screen state and tiles correct.
- Verify diagnostics are redacted.

### Rust tests

- Feed one immutable access unit to N peer tracks.
- Prove one blocked peer cannot block other peers.
- Drop complete access units under pressure without corrupting H.264 framing.
- Consolidate simultaneous PLI/FIR requests.
- Maintain independent RTP sequence, SSRC, retransmission, and encryption
  state.
- Preserve A/V timestamp mapping and recover from discontinuities.
- Release native resources on partial initialization failure and cancellation.

### Windows integration matrix

- Supported and unsupported NVIDIA generations and driver versions.
- One through the configured maximum number of viewers.
- 720p30, 1080p60, 1440p60, and 2160p60 sources.
- Window, borderless game, full display, SDR, and HDR desktop sources.
- Process audio, process tree, system audio, silent source, and device change.
- Direct network, restrictive NAT, and every supported TURN transport.
- Sustained packet loss, low receiver bandwidth, and publisher upload
  saturation.

Collect capture FPS, dropped frames, encode latency percentiles, queue depth,
active NVENC sessions, CPU, GPU Video Encode utilization, outbound bitrate,
packet loss, retransmissions, RTT, and A/V drift.

## Security and privacy

- Preserve the existing mesh IP-address warning and TURN behavior.
- Treat window titles and process names as sensitive diagnostic data.
- Do not log SDP, ICE addresses, access tokens, source titles, or unredacted
  participant identifiers.
- Require the existing room authorization and active participant session for
  secondary signaling.
- Bound event sizes, connection IDs, viewer counts, queues, and retry loops.
- Do not permit remote participants to start capture or select a source.
- Use the operating-system capture consent UI where WGC requires it.
- Avoid injected game capture in the first release because of anti-cheat,
  stability, and trust implications.

## Dependencies and references

Evaluate and pin dependencies only after a license and maintenance review.
Useful implementation references include:

- NVIDIA Video Codec SDK and its D3D11/DXGI samples:
  <https://github.com/NVIDIA/video-sdk-samples>
- Windows Graphics Capture documentation:
  <https://learn.microsoft.com/en-us/windows/apps/develop/media-authoring-processing/screen-capture>
- Windows application-loopback sample:
  <https://learn.microsoft.com/en-us/samples/microsoft/windows-classic-samples/applicationloopbackaudio-sample/>
- webrtc-rs broadcast example:
  <https://github.com/webrtc-rs/webrtc/blob/f4844a0fd2702356b24379d3dd15576e3ad0a1fb/examples/broadcast/broadcast.rs>
- Pion multi-binding RTP track:
  <https://github.com/pion/webrtc/blob/main/track_local_static.go>
- CaptureEngine, an MIT Windows capture and hardware-encoding reference:
  <https://github.com/aufkrawall/capture-engine>
- discord-stream-rs, a young Discord-oriented webrtc-rs/FFmpeg reference:
  <https://github.com/Tky567/stream-discord-rs>

Study GPL or source-available projects only as behavioral references unless a
separate licensing decision explicitly permits incorporating them.

## Decisions to resolve during the spike

- Dart FFI versus generated bridge bindings.
- Rust wrapper around the direct NVENC C API versus a narrow C++ capture/encode
  core behind Rust.
- WGC-only first release versus an early DXGI fallback.
- Exact reference GPU, minimum driver, bitrate, viewer cap, and overload policy.
- Whether the receiving secondary connection should initially use the existing
  browser/native libwebrtc stack or a common Rust receiver on Windows.
- Whether an FFmpeg prototype provides enough schedule advantage to justify its
  temporary build and licensing cost.

These decisions should be made from milestone measurements. They do not change
the protocol boundary or the encode-once/per-peer-transport architecture.
