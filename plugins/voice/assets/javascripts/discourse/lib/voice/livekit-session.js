// LiveKit room session.
//
// One instance per active room on the "livekit" transport, owned by the
// voice-webrtc service. Bridges the vendored livekit-client SDK to the
// same callbacks PeerManager uses, so the remote-media registry and every
// UI component work unchanged on both transports. Callback-injected in the
// same style as PeerManager; a fake SDK module can be injected via `loadSdk`
// (or the module-level test override), which is what makes it unit-testable.

import {
  cameraEncodingFor,
  screenEncodingFor,
  voiceBitrateFor,
} from "./video-quality";
import { voiceAssetAppUrl } from "./voice-assets";

// The SDK bundle sits in the plugin's public dir, which static asset CDNs
// never receive. Anchor to the page URL because this compiled chunk may
// itself be served from a CDN origin, and a dynamic import() of a bare path
// would resolve against the chunk's origin, not the site's. The loaded
// module stays resident so rejoins are instant; never evaluated for mesh
// rooms. The bundle keeps a .js extension (despite being ESM) because
// module scripts require a JavaScript MIME type and neither Rails' static
// file server nor stock nginx maps .mjs to one.
let sdkPromise = null;
let sdkLoaderOverride = null;

// Reconnect ladder: wait entry N, then mint a fresh token and connect.
let reconnectDelaysMs = [0, 1000, 2000];

async function defaultLoadSdk() {
  sdkPromise ||= import(
    /* @vite-ignore */ voiceAssetAppUrl("livekit/livekit-client.js")
  );

  try {
    return await sdkPromise;
  } catch (error) {
    // Allow a retry after a transient failure (e.g. offline asset fetch).
    sdkPromise = null;
    throw error;
  }
}

export function setLivekitSdkLoaderForTesting(loader) {
  sdkLoaderOverride = loader;
  sdkPromise = null;
}

export function setLivekitReconnectDelaysForTesting(delays) {
  reconnectDelaysMs = delays ?? [0, 1000, 2000];
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Publish ceilings mirror the mesh sender ladder's top rungs for the active
// quality tier and the capture-time caps; simulcast gives the SFU lower
// layers to hand to constrained subscribers instead of the mesh's
// per-watcher encoder ladder. Unlike the mesh, higher tiers here cost the
// publisher a single encode regardless of viewer count.
// Content audio: higher Opus ceiling than the speech default so screen audio
// doesn't sound underwater.
const SCREEN_AUDIO_BITRATE = 128_000;
// Camera subscriptions drop to the LOW simulcast layer above this many
// active video publishers — the same threshold the mesh bitrate ladder uses.
const LOW_LAYER_PUBLISHER_THRESHOLD = 6;

export default class LivekitRoomSession {
  // Cheap pre-load check so obviously unsupported browsers fail with a
  // translated toast instead of a dynamic-import error; the SDK's own
  // isBrowserSupported() runs again after the bundle loads.
  static isBrowserSupported() {
    return (
      typeof RTCPeerConnection !== "undefined" &&
      typeof WebSocket !== "undefined"
    );
  }

  #roomId;
  #currentUserId;
  #loadSdk;
  #getLocalStream;
  #getLocalVideoTrack;
  #getLocalScreenAudioTrack;
  #getLocalVideoKind;
  #getVideoPublisherCount;
  #onTrack;
  #onParticipantGone;
  #onDisconnected;
  #onConnectionChange;
  #mintToken;
  #getQualityTiers;

  #sdk = null;
  #room = null;
  #micPublication = null;
  #videoPublication = null;
  #videoKind = null;
  #screenAudioPublication = null;
  #watchingVideo = false;
  #closed = false;
  #reconnecting = false;

  constructor({
    roomId,
    currentUserId,
    loadSdk,
    getLocalStream,
    getLocalVideoTrack,
    getLocalScreenAudioTrack,
    getLocalVideoKind,
    getVideoPublisherCount,
    onTrack,
    onParticipantGone,
    onDisconnected,
    onConnectionChange,
    mintToken,
    getQualityTiers,
  }) {
    this.#roomId = roomId;
    this.#currentUserId = currentUserId;
    this.#loadSdk = loadSdk ?? sdkLoaderOverride ?? defaultLoadSdk;
    this.#getLocalStream = getLocalStream;
    this.#getLocalVideoTrack = getLocalVideoTrack;
    this.#getLocalScreenAudioTrack = getLocalScreenAudioTrack;
    this.#getLocalVideoKind = getLocalVideoKind;
    this.#getVideoPublisherCount = getVideoPublisherCount;
    this.#onTrack = onTrack;
    this.#onParticipantGone = onParticipantGone;
    this.#onDisconnected = onDisconnected;
    this.#onConnectionChange = onConnectionChange;
    this.#mintToken = mintToken;
    this.#getQualityTiers = getQualityTiers;
  }

  async connect(wsUrl, token) {
    this.#sdk ||= await this.#loadSdk();

    if (
      typeof this.#sdk.isBrowserSupported === "function" &&
      !this.#sdk.isBrowserSupported()
    ) {
      const error = new Error("LiveKit is not supported in this browser");
      error.unsupportedBrowser = true;
      throw error;
    }

    // adaptiveStream keys quality off attached-element visibility, which is
    // incompatible with service-owned elements (it would pause "invisible"
    // video); subscriber-side quality is managed explicitly instead.
    const room = new this.#sdk.Room({
      adaptiveStream: false,
      dynacast: true,
    });

    this.#wireRoomEvents(room);

    try {
      await room.connect(wsUrl, token);
    } catch (error) {
      room.removeAllListeners?.();
      throw error;
    }

    // The session may have been torn down while the connect was in flight
    // (superseded join, leave); adopting the room now would leave a ghost
    // connection to the SFU that nothing owns.
    if (this.#closed) {
      room.removeAllListeners?.();
      try {
        await room.disconnect();
      } catch {
        // Nothing to clean up.
      }
      return;
    }

    this.#room = room;
    this.#micPublication = null;
    this.#videoPublication = null;
    this.#videoKind = null;
    this.#screenAudioPublication = null;
    await this.#publishMicrophone();

    // A ladder reconnect lands on a fresh Room; whatever camera or screen
    // share was live before the drop must be republished.
    await this.syncLocalVideo(
      this.#getLocalVideoTrack?.(),
      this.#getLocalScreenAudioTrack?.(),
      this.#getLocalVideoKind?.()
    );
  }

  async disconnect() {
    this.#closed = true;
    const room = this.#room;
    this.#room = null;
    this.#micPublication = null;
    this.#videoPublication = null;
    this.#videoKind = null;
    this.#screenAudioPublication = null;

    try {
      await room?.disconnect();
    } catch {
      // The room may already be closed; nothing to clean up.
    }
  }

  // NS toggle, mic device switch, and gate crossings produce a brand-new
  // outgoing track; move the live publication onto it.
  async replaceAudioTrack(track) {
    if (!this.#room || !track) {
      return;
    }

    if (this.#micPublication?.track) {
      await this.#micPublication.track.replaceTrack(track);
    } else {
      await this.#publishMicrophone();
    }
  }

  // Brings the video and screen-audio publications in line with the local
  // capture state. The mesh equivalent gates per watching peer; on the SFU
  // media is published once and receive gating moves to the subscriber side.
  async syncLocalVideo(videoTrack, screenAudioTrack, kind) {
    if (!this.#room) {
      return;
    }

    await this.#syncVideoPublication(videoTrack ?? null, kind ?? null);
    await this.#syncScreenAudioPublication(
      videoTrack ? (screenAudioTrack ?? null) : null
    );
  }

  // Receive gating for the watching state: non-watchers unsubscribe from
  // camera, screen, and screen-audio publications so they cost no downlink.
  // Microphones are never gated. Publications created while not watching are
  // caught by the TrackPublished and TrackSubscribed handlers.
  setVideoSubscriptionsEnabled(watching) {
    this.#watchingVideo = !!watching;

    this.#room?.remoteParticipants?.forEach((participant) => {
      participant.trackPublications?.forEach((publication) => {
        this.#applyDesiredSubscription(publication);
      });
    });
  }

  // Re-picks simulcast layers for current subscriptions; called when the
  // room's video publisher count changes.
  updateSubscriberQuality() {
    this.#room?.remoteParticipants?.forEach((participant) => {
      participant.trackPublications?.forEach((publication) => {
        if (publication?.isSubscribed) {
          this.#applySubscriberQuality(publication);
        }
      });
    });
  }

  // Role changes flip whether the local user may hold a live microphone
  // publication; re-evaluate against the current local stream. The media
  // session itself survives the role change (unlike mesh peer rebuilds).
  async refreshPublications() {
    if (!this.#room) {
      return;
    }

    const track = this.#getLocalStream?.()?.getAudioTracks?.()?.[0];

    if (!track) {
      const publication = this.#micPublication;
      this.#micPublication = null;
      await this.#unpublish(publication);
      return;
    }

    if (this.#micPublication?.track) {
      if (this.#micPublication.track.mediaStreamTrack !== track) {
        await this.#micPublication.track.replaceTrack(track);
      }
      return;
    }

    await this.#publishMicrophone();
  }

  // The SFU doesn't consult the plugin's roster, so a participant expelled
  // from it can still hold live subscriptions; drop them explicitly.
  dropParticipant(userId) {
    const participant = this.#room?.remoteParticipants?.get(String(userId));

    participant?.trackPublications?.forEach((publication) => {
      try {
        publication.setSubscribed(false);
      } catch {
        // Already unsubscribed or tearing down.
      }
    });
  }

  // Terminal-disconnect recovery: up to three attempts, each awaiting a
  // freshly minted token (the old one is likely past its 10-minute TTL).
  // Resolves "reconnected", "gone" (server says the room instance ended),
  // "aborted" (session torn down mid-ladder), or "failed" (exhausted).
  async reconnectWithToken() {
    if (this.#reconnecting) {
      return "failed";
    }
    this.#reconnecting = true;

    try {
      for (const delayMs of reconnectDelaysMs) {
        if (delayMs > 0) {
          await wait(delayMs);
        }
        if (this.#closed) {
          return "aborted";
        }

        let minted;
        try {
          minted = await this.#mintToken();
        } catch (error) {
          if ((error?.jqXHR?.status ?? error?.status) === 410) {
            return "gone";
          }
          continue;
        }

        if (this.#closed) {
          return "aborted";
        }

        try {
          await this.connect(minted.url, minted.token);
          return this.#closed ? "aborted" : "reconnected";
        } catch (error) {
          // eslint-disable-next-line no-console
          console.warn(
            `[voice-livekit] reconnect attempt failed for room ${this.#roomId}`,
            error
          );
        }
      }

      return this.#closed ? "aborted" : "failed";
    } finally {
      this.#reconnecting = false;
    }
  }

  // Effective tiers already clamped by the service (user choice vs room and
  // site caps). Read at publish time, so a changed preference applies on the
  // next publish without renegotiating current ones.
  #qualityTiers() {
    return this.#getQualityTiers?.() ?? {};
  }

  async #syncVideoPublication(track, kind) {
    // A camera→screen switch changes the publication source, so the old
    // publication can't be retracked in place.
    if (this.#videoPublication && (!track || this.#videoKind !== kind)) {
      const publication = this.#videoPublication;
      this.#videoPublication = null;
      this.#videoKind = null;
      await this.#unpublish(publication);
    }

    if (!track || !kind) {
      return;
    }

    if (this.#videoPublication?.track) {
      // Same kind, new track: device switch or blur pipeline swap.
      if (this.#videoPublication.track.mediaStreamTrack !== track) {
        await this.#videoPublication.track.replaceTrack(track);
      }
      return;
    }

    const { Track } = this.#sdk;
    const tiers = this.#qualityTiers();
    const encoding =
      kind === "screen"
        ? screenEncodingFor(tiers.screen)
        : cameraEncodingFor(tiers.camera);
    const livekitEncoding = {
      maxBitrate: encoding.maxBitrate,
      maxFramerate: encoding.maxFramerate,
    };
    const options =
      kind === "screen"
        ? {
            source: Track.Source.ScreenShare,
            simulcast: true,
            screenShareEncoding: livekitEncoding,
          }
        : {
            source: Track.Source.Camera,
            simulcast: true,
            videoEncoding: livekitEncoding,
          };

    try {
      this.#videoPublication = await this.#room.localParticipant.publishTrack(
        track,
        options
      );
      this.#videoKind = kind;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn(
        `[voice-livekit] failed to publish ${kind} video for room ${this.#roomId}`,
        error
      );
    }
  }

  async #syncScreenAudioPublication(track) {
    const current = this.#screenAudioPublication;
    if (current && current.track?.mediaStreamTrack !== track) {
      this.#screenAudioPublication = null;
      await this.#unpublish(current);
    }

    if (!track || this.#screenAudioPublication) {
      return;
    }

    try {
      this.#screenAudioPublication =
        await this.#room.localParticipant.publishTrack(track, {
          source: this.#sdk.Track.Source.ScreenShareAudio,
          // DTX is tuned for speech pauses and would gate content audio.
          dtx: false,
          audioBitrate: SCREEN_AUDIO_BITRATE,
        });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn(
        `[voice-livekit] failed to publish screen audio for room ${this.#roomId}`,
        error
      );
    }
  }

  async #unpublish(publication) {
    if (!publication?.track || !this.#room) {
      return;
    }

    try {
      // The service owns capture-track lifecycle; never stop on unpublish
      // (a blur pipeline may still be feeding the track).
      await this.#room.localParticipant.unpublishTrack(
        publication.track,
        false
      );
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn(
        `[voice-livekit] failed to unpublish a track for room ${this.#roomId}`,
        error
      );
    }
  }

  #isWatchGatedSource(source) {
    const { Track } = this.#sdk;
    return (
      source === Track.Source.Camera ||
      source === Track.Source.ScreenShare ||
      source === Track.Source.ScreenShareAudio
    );
  }

  #applyDesiredSubscription(publication) {
    if (!this.#isWatchGatedSource(publication?.source)) {
      return;
    }

    try {
      publication.setSubscribed(this.#watchingVideo);
    } catch {
      // The publication is tearing down; nothing to gate.
    }
  }

  // With adaptiveStream off the SDK would leave every subscription on the
  // HIGH simulcast layer, regressing downlink vs the mesh ladder in big
  // rooms; pick layers explicitly instead.
  #applySubscriberQuality(publication) {
    const { Track, VideoQuality } = this.#sdk;

    let quality;
    if (publication?.source === Track.Source.ScreenShare) {
      quality = VideoQuality.HIGH;
    } else if (publication?.source === Track.Source.Camera) {
      const publisherCount = this.#getVideoPublisherCount?.() ?? 0;
      quality =
        publisherCount > LOW_LAYER_PUBLISHER_THRESHOLD
          ? VideoQuality.LOW
          : VideoQuality.MEDIUM;
    } else {
      return;
    }

    try {
      publication.setVideoQuality(quality);
    } catch {
      // The publication is tearing down; the next subscription re-applies.
    }
  }

  #userIdFrom(participant) {
    // LiveKit identity is String(user.id); registry keys must be numeric so
    // remoteStreamFor(roomId, userId) matches roster participant ids.
    const userId = Number(participant?.identity);
    if (!Number.isFinite(userId) || userId <= 0) {
      return null;
    }
    return userId === this.#currentUserId ? null : userId;
  }

  #wireRoomEvents(room) {
    const { RoomEvent, Track, DisconnectReason } = this.#sdk;

    room.on(RoomEvent.TrackSubscribed, (track, publication, participant) => {
      const userId = this.#userIdFrom(participant);
      if (!userId) {
        return;
      }

      // Auto-subscribe can deliver watch-gated media before the gate applies
      // (publications that already existed when the room connected); drop the
      // subscription instead of registering a soundtrack or video nobody is
      // watching.
      if (
        this.#isWatchGatedSource(publication?.source) &&
        !this.#watchingVideo
      ) {
        this.#applyDesiredSubscription(publication);
        return;
      }

      if (track.kind === "video") {
        this.#applySubscriberQuality(publication);
      }

      // A bare audio track (empty streams argument) is how screen audio is
      // told apart from mic audio in #registerRemoteTrack; every other kind
      // must arrive with a stream attached.
      const isScreenAudio =
        publication?.source === Track.Source.ScreenShareAudio;
      const streams = isScreenAudio
        ? []
        : [track.mediaStream ?? new MediaStream()];

      this.#onTrack(this.#roomId, userId, track.mediaStreamTrack, streams);
    });

    room.on(RoomEvent.TrackPublished, (publication) => {
      // A camera or screen published while this client isn't watching must
      // start unsubscribed; auto-subscribe only covers what existed at
      // connect time.
      this.#applyDesiredSubscription(publication);
    });

    room.on(RoomEvent.ParticipantPermissionsChanged, (_prev, participant) => {
      if (participant !== room.localParticipant) {
        return;
      }

      // A server-side permission update (e.g. a promotion synced by the
      // backend) lets the mic publish without a reconnect.
      this.refreshPublications().catch((error) => {
        // eslint-disable-next-line no-console
        console.warn(
          `[voice-livekit] failed to refresh publications for room ${this.#roomId}`,
          error
        );
      });
    });

    room.on(RoomEvent.TrackUnsubscribed, (track, publication, participant) => {
      const userId = this.#userIdFrom(participant);
      if (!userId) {
        return;
      }

      // Losing the microphone (server-side unpublish, e.g. a permission
      // revocation) drops the participant's media entry; it is rebuilt from
      // scratch if the mic is ever re-subscribed. Video and screen-audio
      // subscriptions come and go with watching state, so they must not
      // tear the entry down.
      if (publication?.source === Track.Source.Microphone) {
        this.#onParticipantGone(this.#roomId, userId);
      }
    });

    room.on(RoomEvent.ParticipantDisconnected, (participant) => {
      const userId = this.#userIdFrom(participant);
      if (userId) {
        this.#onParticipantGone(this.#roomId, userId);
      }
    });

    room.on(RoomEvent.Disconnected, (reason) => {
      if (room !== this.#room || this.#closed) {
        return;
      }

      this.#room = null;
      this.#micPublication = null;
      this.#videoPublication = null;
      this.#videoKind = null;
      this.#screenAudioPublication = null;

      if (reason === DisconnectReason.CLIENT_INITIATED) {
        return;
      }

      const kind =
        reason === DisconnectReason.DUPLICATE_IDENTITY
          ? "duplicate_identity"
          : "terminal";
      this.#onDisconnected(kind, DisconnectReason[reason] ?? String(reason));
    });

    room.on(RoomEvent.Reconnecting, () => {
      // eslint-disable-next-line no-console
      console.log(
        `[voice-livekit] connection interrupted for room ${this.#roomId}; SDK is resuming`
      );
      this.#onConnectionChange("reconnecting");
    });

    room.on(RoomEvent.Reconnected, () => {
      // eslint-disable-next-line no-console
      console.log(
        `[voice-livekit] connection resumed for room ${this.#roomId}`
      );
      this.#onConnectionChange("connected");
    });
  }

  async #publishMicrophone() {
    const track = this.#getLocalStream?.()?.getAudioTracks?.()?.[0];
    if (!track || !this.#room) {
      return;
    }

    try {
      // The pipeline's processed tracks publish as-is; mute/PTT keep
      // flipping track.enabled, so the SFU carries DTX-suppressed silence
      // instead of a mute/unmute renegotiation.
      const micOptions = {
        source: this.#sdk.Track.Source.Microphone,
        dtx: true,
        red: true,
      };
      const voiceBitrate = voiceBitrateFor(this.#qualityTiers().voice);
      if (voiceBitrate) {
        micOptions.audioBitrate = voiceBitrate;
      }
      this.#micPublication = await this.#room.localParticipant.publishTrack(
        track,
        micOptions
      );
    } catch (error) {
      // A rejected publish (e.g. a stale token after a role change) must
      // not fail the join — the user can still listen.
      // eslint-disable-next-line no-console
      console.warn(
        `[voice-livekit] failed to publish microphone for room ${this.#roomId}`,
        error
      );
    }
  }
}
