# Local (In-Browser) Recording

## Overview

Server-side recording only exists for LiveKit calls (`Live::RecordingManager`
drives LiveKit Egress). Mesh calls have no server in the media path, so there
is nothing to record from. This plan adds **local recording**: a participant
records the call in their own browser with `MediaRecorder`, and the file never
leaves their machine.

Nothing about this is mesh-specific. It also serves LiveKit calls on sites
without Egress configured, or users who can't start server recordings, so it
ships as its own "Record locally" control instead of a mesh workaround.

What the server does get involved in is **visibility**: a local recording
raises the same room-wide "Recording" indicator that LiveKit recordings
already use (`LiveRecordingBadge`).

## Why not just capture the tab with its audio

`getDisplayMedia({ audio: true, preferCurrentTab: true })` looks like a
one-liner, but tab audio is the wrong audio source:

- **The recorder's own mic is missing.** The tab never plays the local user
  back to themselves, so the recording has everyone except the person
  recording.
- **Browser support.** Only Chromium captures tab audio. Firefox has no audio
  in `getDisplayMedia`; Safari can't capture a single tab or its audio. Mobile
  browsers have no `getDisplayMedia` at all.
- **Local output settings leak in.** Per-user volume, deafen, and output-sink
  changes all shape what the tab plays.

So the design splits the two: **audio is mixed by us, video comes from
display capture.**

## Design

### Audio: Web Audio mix

All the inputs are already in the client:

- remote mic streams — `RemoteStreamRegistry#allStreams()`
- remote screen-share audio — `RemoteStreamRegistry#allScreenAudioStreams()`
- the local mic, after noise suppression and the input gate / push-to-talk,
  so the recording matches what other participants actually heard

Each feeds a `MediaStreamAudioSourceNode` into one shared
`createMediaStreamDestination()` (the same pattern as `noise-suppression.js`
and `input-gate.js`). The registry's `onChange` adds and removes sources as
peers join, leave, or start sharing. Both transports feed the registry, so the
mixer is transport-agnostic.

This works in every browser and needs no permission prompt.

### Video: display capture (optional)

```js
navigator.mediaDevices.getDisplayMedia({
  video: true,
  audio: false,
  preferCurrentTab: true,
  selfBrowserSurface: "include",
  surfaceSwitching: "exclude",
});
```

- In Chromium, `preferCurrentTab` reduces the prompt to a single "share this
  tab" confirmation.
- In Firefox and Safari the user picks a window or screen instead.
- If display capture is unavailable or declined, record audio only.

Rejected: compositing video tiles onto a `<canvas>` with `captureStream()`.
Browsers throttle `requestAnimationFrame` in hidden tabs, so the video stalls
as soon as the user switches tabs. Display capture doesn't have that problem.

### Recording and storage

- One `MediaStream` holding the display video track (if any) and the mixed
  audio track goes into `MediaRecorder`.
- Pick the container with `MediaRecorder.isTypeSupported`:
  `video/mp4;codecs=avc1,opus` where available (recent Chromium, Safari),
  otherwise `video/webm;codecs=vp9,opus`; audio-only uses `audio/mp4` or
  `audio/webm;codecs=opus`.
- Don't buffer chunks in memory (an hour of 720p is several hundred MB).
  `start(timeslice)` streams one-second chunks to a file in the origin-private
  file system (OPFS), falling back to memory where OPFS writes aren't
  available. The file is downloaded when the recording stops.
  `showSaveFilePicker()` was rejected: it needs its own user gesture, which
  the capture prompt has already used up.
- WebM from `MediaRecorder` has no duration or cues, so players can't seek it.
  Prefer MP4; if WebM fix-up is needed, the dependency goes into core behind a
  `load-*.js` wrapper (plugins can't import npm modules).

### Lifecycle

Stop and finalize on:

- the record button being pressed again
- the display track's `ended` event (the browser's own "Stop sharing" bar)
- leaving the call or switching rooms

While recording, a `beforeunload` guard warns before a reload, because
anything not yet flushed is lost.

The menu entry binds its handler with `{{on "click"}}` rather than `DButton`'s
`@action`: Firefox only allows `getDisplayMedia` during the click dispatch
itself, and `@action` defers via `next()`.

## Controls

One "Record to this device" entry in the room's overflow (kebab) menu, on both
the room page and the call widget, not separate audio and video entries. The
recording badge already makes a running recording visible, so the control
doesn't need a spot in the call controls.

1. Browsers without `getDisplayMedia` (mobile) record audio only right away.
2. Otherwise the click opens the tab-capture prompt. If it is declined or
   fails, a dialog offers an audio-only recording instead.
3. Choosing the entry again stops the recording and downloads the file
   (through `deliverBlobDownload`, so the mobile app bridge works too).

Where the user can start a server (LiveKit) recording, the entry is hidden, so
nobody sees two ways to record.

## Reusing the recording indicator

`LiveRecordingBadge` already renders wherever a call is shown (room header,
call widget). It now shows for a server recording (`room.recording`), for the
current user's own local recording, or for any participant whose roster entry
has `is_recording_locally`. The tooltip lists each source on its own line.

The flag follows the transcript's `is_transcribing` precedent instead of a new
Redis key:

- `POST /live/rooms/:id/state` takes `recording_locally`. Turning it on
  requires `can_record_live_locally?`; turning it off is always allowed.
- It lives in participant metadata, so leave, kick, rejoin and presence expiry
  clear it with no extra cleanup, and the existing participants broadcast
  carries it.
- Participants who start recording after you joined are announced with a
  toast, as server recordings are. Recordings already running when you join
  are shown by the badge only.
- A server recording and local recordings never block each other.

The indicator is good-faith only. Nothing stops anyone running an OS screen
recorder; the feature makes the built-in path visible.

## Settings

- `live_local_recording_allowed_groups`: empty by default, which turns the
  feature off. Exposed to the client as `current_user.live_can_record_locally`.

## Not built yet

- Cropping the capture to the call area with Element Capture
  (`RestrictionTarget`) or Region Capture (`CropTarget`). The element must
  stay rendered, and the call widget follows the user across pages, so
  restricting to it would freeze the video on navigation. Needs a design for
  the widget case first.
- Recovering a recording left in storage by a crashed tab. Files older than an
  hour are deleted when the next recording starts.

## Testing

- RSpec: the `recording_locally` state flag (allowed, rejected, always
  clearable) and `can_record_live_locally?`.
- QUnit: container and filename choice, new-recorder announcements, the
  record button's audio-only, tab-capture and fallback paths, and the badge's
  titles.
- Not covered automatically: real capture and recording, which headless
  browsers can't exercise. Verify manually in Chromium, Firefox and Safari.
