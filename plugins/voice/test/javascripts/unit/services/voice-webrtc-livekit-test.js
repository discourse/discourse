import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Site from "discourse/models/site";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import {
  setLivekitReconnectDelaysForTesting,
  setLivekitSdkLoaderForTesting,
} from "discourse/plugins/voice/discourse/lib/voice/livekit-session";
import { setPeerTimingForTesting } from "discourse/plugins/voice/discourse/lib/voice/peer-manager";

// Park the mesh peer machinery's wall-clock timers far outside any test's
// window. This suite mostly runs on the livekit transport, but its mesh
// tests still create peers whose fallback-offer/restart timers would
// otherwise fire mid-test under CI load (QUnit shuffles test order every
// run, so a late firing poisons whichever test happens to be running).
const SAFE_PEER_TIMING = {
  offerRetryBaseDelayMs: 60_000,
  maxOfferRetryDelayMs: 60_000,
  restartImmediateDelayMs: 60_000,
  restartDisconnectedDelayMs: 60_000,
  maxRestartDelayMs: 60_000,
  connectionTimeoutMs: 60_000,
};

class VoiceRoomsStub extends Service {
  #roomHandlers = new Map();
  #roomsById = new Map();

  seedRoom(room) {
    this.#roomsById.set(room.id, room);
  }

  roomById(id) {
    return this.#roomsById.get(id);
  }

  registerRoomHandler(roomId, callback) {
    let callbacks = this.#roomHandlers.get(roomId);

    if (!callbacks) {
      callbacks = new Set();
      this.#roomHandlers.set(roomId, callbacks);
    }

    callbacks.add(callback);
  }

  unregisterRoomHandler(roomId, callback) {
    const callbacks = this.#roomHandlers.get(roomId);
    if (!callbacks) {
      return;
    }

    callbacks.delete(callback);
    if (!callbacks.size) {
      this.#roomHandlers.delete(roomId);
    }
  }

  emit(roomId, payload) {
    const room = this.#roomsById.get(roomId);

    if (payload.type === "participants" && room) {
      room.active_participants = payload.participants;
    }

    this.#roomHandlers.get(roomId)?.forEach((callback) => callback(payload));
  }

  addParticipant(roomId, participant) {
    const room = this.#roomsById.get(roomId);
    if (!room) {
      return;
    }

    const existing = room.active_participants || [];
    if (existing.some((entry) => Number(entry.id) === Number(participant.id))) {
      return;
    }

    room.active_participants = [...existing, participant];
  }

  removeParticipant(roomId, userId) {
    const room = this.#roomsById.get(roomId);
    if (!room) {
      return;
    }

    room.active_participants = (room.active_participants || []).filter(
      (participant) => Number(participant.id) !== Number(userId)
    );
  }

  setParticipantMuted() {}
  setParticipantDeafened() {}
  setParticipantSpeaking() {}
  setParticipantIdleState() {}
  setParticipantVideoState() {}
}

class RecordingToastsStub extends Service {
  errors = [];
  defaults = [];

  error(args) {
    this.errors.push(args);
  }

  success() {}

  default(args) {
    this.defaults.push(args);
  }
}

class FakeRTCPeerConnection {
  static created = 0;

  constructor() {
    FakeRTCPeerConnection.created++;
  }

  addTrack() {
    return { track: null, async replaceTrack() {} };
  }

  addTransceiver() {
    return {
      direction: "sendrecv",
      sender: { track: null, async replaceTrack() {} },
      receiver: { track: null },
    };
  }

  getTransceivers() {
    return [];
  }

  getSenders() {
    return [];
  }

  async createOffer() {
    return { type: "offer", sdp: "fake-offer" };
  }

  async setLocalDescription() {}

  close() {}
}

// A minimal livekit-client stand-in exposing exactly the surface
// LivekitRoomSession touches, injected via the module test loader.
function buildFakeSdk() {
  const RoomEvent = {
    TrackSubscribed: "trackSubscribed",
    TrackUnsubscribed: "trackUnsubscribed",
    TrackPublished: "trackPublished",
    ParticipantDisconnected: "participantDisconnected",
    ParticipantPermissionsChanged: "participantPermissionsChanged",
    Disconnected: "disconnected",
    Reconnecting: "reconnecting",
    Reconnected: "reconnected",
  };

  const VideoQuality = {
    LOW: 0,
    MEDIUM: 1,
    HIGH: 2,
  };

  const DisconnectReason = {
    UNKNOWN_REASON: 0,
    CLIENT_INITIATED: 1,
    DUPLICATE_IDENTITY: 2,
    SERVER_SHUTDOWN: 3,
    0: "UNKNOWN_REASON",
    1: "CLIENT_INITIATED",
    2: "DUPLICATE_IDENTITY",
    3: "SERVER_SHUTDOWN",
  };

  const Track = {
    Source: {
      Camera: "camera",
      Microphone: "microphone",
      ScreenShare: "screen_share",
      ScreenShareAudio: "screen_share_audio",
    },
  };

  class FakeLivekitRoom {
    static instances = [];
    static connectErrors = [];

    options;
    connectCalls = [];
    disconnectCalls = 0;
    remoteParticipants = new Map();
    #handlers = new Map();

    constructor(options) {
      this.options = options;
      FakeLivekitRoom.instances.push(this);

      const room = this;
      this.localParticipant = {
        published: [],
        unpublishCalls: [],
        async publishTrack(track, publishOptions) {
          const publication = {
            source: publishOptions?.source,
            options: publishOptions,
            track: {
              mediaStreamTrack: track,
              replaceCalls: [],
              async replaceTrack(newTrack) {
                this.mediaStreamTrack = newTrack;
                this.replaceCalls.push(newTrack);
              },
            },
          };
          room.localParticipant.published.push(publication);
          return publication;
        },
        async unpublishTrack(track, stopOnUnpublish) {
          room.localParticipant.unpublishCalls.push({ track, stopOnUnpublish });
          room.localParticipant.published =
            room.localParticipant.published.filter(
              (publication) => publication.track !== track
            );
        },
      };
    }

    on(event, handler) {
      const handlers = this.#handlers.get(event) || [];
      handlers.push(handler);
      this.#handlers.set(event, handlers);
      return this;
    }

    emit(event, ...args) {
      (this.#handlers.get(event) || []).forEach((handler) => handler(...args));
    }

    async connect(url, token) {
      this.connectCalls.push({ url, token });

      const error = FakeLivekitRoom.connectErrors.shift();
      if (error) {
        throw error;
      }
    }

    async disconnect() {
      this.disconnectCalls++;
    }

    removeAllListeners() {
      this.#handlers.clear();
    }
  }

  return {
    sdk: {
      Room: FakeLivekitRoom,
      RoomEvent,
      DisconnectReason,
      Track,
      VideoQuality,
      isBrowserSupported: () => true,
    },
    FakeLivekitRoom,
  };
}

function createFakeRemotePublication(source, kind) {
  return {
    source,
    kind,
    isSubscribed: true,
    subscribedCalls: [],
    qualityCalls: [],
    setSubscribed(value) {
      this.isSubscribed = value;
      this.subscribedCalls.push(value);
    },
    setVideoQuality(quality) {
      this.qualityCalls.push(quality);
    },
  };
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitUntil(callback, timeout = 500) {
  const startedAt = Date.now();

  while (!callback()) {
    if (Date.now() - startedAt > timeout) {
      throw new Error("Timed out waiting for condition");
    }
    await wait(10);
  }
}

function createFakeTrack(id, kind = "audio") {
  return {
    id,
    kind,
    enabled: true,
    stop() {},
    addEventListener() {},
  };
}

function createFakeStream(id, track) {
  return {
    id,
    getTracks() {
      return [track];
    },
    getAudioTracks() {
      return [track];
    },
  };
}

function createFakeMediaStream(id, tracks) {
  return {
    id,
    getTracks: () => [...tracks],
    getAudioTracks: () => tracks.filter((track) => track.kind === "audio"),
    getVideoTracks: () => tracks.filter((track) => track.kind === "video"),
  };
}

function installFakeAudioEnvironment({ rawStream, processedStream }) {
  const originalAudioContext = globalThis.AudioContext;
  const originalAudioWorkletNode = globalThis.AudioWorkletNode;
  const originalRequestAnimationFrame = window.requestAnimationFrame;
  const originalCancelAnimationFrame = window.cancelAnimationFrame;
  const originalWindowAudioContext = window.AudioContext;
  const originalWindowWebkitAudioContext = window.webkitAudioContext;
  const originalGetUserMedia = navigator.mediaDevices?.getUserMedia;

  class FakeAudioContext {
    currentTime = 0;
    state = "running";
    destination = {};
    audioWorklet = {
      addModule: async () => {},
    };

    resume() {
      this.state = "running";
      return Promise.resolve();
    }

    createMediaStreamSource() {
      return {
        connect(target) {
          return target;
        },
        disconnect() {},
      };
    }

    createAnalyser() {
      return {
        fftSize: 0,
        frequencyBinCount: 32,
        getByteTimeDomainData(array) {
          array.fill(128);
        },
      };
    }

    createMediaStreamDestination() {
      return { stream: processedStream };
    }

    createOscillator() {
      return {
        frequency: { value: 0 },
        connect(target) {
          return target;
        },
        start() {},
        stop() {},
      };
    }

    createGain() {
      return {
        gain: {
          setValueAtTime() {},
          exponentialRampToValueAtTime() {},
        },
        connect(target) {
          return target;
        },
      };
    }

    close() {
      return Promise.resolve();
    }
  }

  // Mirrors the DTLN worklet protocol: the manager posts the wasm bytes and
  // waits for "ready" before publishing the suppressed stream.
  class FakeAudioWorkletNode {
    port = {
      onmessage: null,
      postMessage: (data) => {
        if (data?.type === "init") {
          Promise.resolve().then(() =>
            this.port.onmessage?.({ data: { type: "ready" } })
          );
        }
      },
    };

    connect(target) {
      return target;
    }

    disconnect() {}
  }

  // The gem-vendored asset base the loaders read at runtime.
  Site.current().set("voice_assets_path", "/plugins/voice/javascripts/0.0.0");

  const originalFetch = globalThis.fetch;
  const fakeFetch = (url, options) => {
    if (String(url).includes("/plugins/voice/javascripts/")) {
      return Promise.resolve({
        ok: true,
        arrayBuffer: async () => new ArrayBuffer(8),
      });
    }
    return originalFetch(url, options);
  };

  globalThis.AudioContext = FakeAudioContext;
  globalThis.AudioWorkletNode = FakeAudioWorkletNode;
  globalThis.fetch = fakeFetch;
  window.AudioContext = FakeAudioContext;
  window.webkitAudioContext = FakeAudioContext;
  window.requestAnimationFrame = () => 1;
  window.cancelAnimationFrame = () => {};

  navigator.mediaDevices ||= {};
  navigator.mediaDevices.getUserMedia = async () => rawStream;

  return {
    restore() {
      globalThis.AudioContext = originalAudioContext;
      globalThis.AudioWorkletNode = originalAudioWorkletNode;
      globalThis.fetch = originalFetch;
      window.AudioContext = originalWindowAudioContext;
      window.webkitAudioContext = originalWindowWebkitAudioContext;
      window.requestAnimationFrame = originalRequestAnimationFrame;
      window.cancelAnimationFrame = originalCancelAnimationFrame;

      if (originalGetUserMedia) {
        navigator.mediaDevices.getUserMedia = originalGetUserMedia;
      } else {
        delete navigator.mediaDevices.getUserMedia;
      }
    },
  };
}

module("Voice | Unit | Service | voice-webrtc-livekit", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    setPeerTimingForTesting(SAFE_PEER_TIMING);
    this.currentUser = logIn(this.owner);
    this.currentUser.id = 10;
    this.keyValueStore = this.owner.lookup("service:key-value-store");
    this.cameraPreferenceKey = `voice-camera-enabled-${this.currentUser.id}`;
    this.keyValueStore.remove(this.cameraPreferenceKey);
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.siteSettings.voice_auto_status_enabled = true;
    this.siteSettings.voice_video_max_publishers = 4;
    localStorage.removeItem("voice:noise-suppression");
    localStorage.removeItem("voice:noise-suppression-mode");

    this.owner.unregister("service:voice-rooms");
    this.owner.register("service:voice-rooms", VoiceRoomsStub);
    this.owner.unregister("service:toasts");
    this.owner.register("service:toasts", RecordingToastsStub);

    this.rooms = this.owner.lookup("service:voice-rooms");
    this.toasts = this.owner.lookup("service:toasts");
    this.room = {
      id: 1,
      name: "Voice",
      room_type: "open",
      video_enabled: true,
      video_allowed: true,
      screen_share_allowed: true,
      membership: { role_name: "participant" },
      active_participants: [
        { id: this.currentUser.id, role: "participant" },
        { id: 2, role: "participant" },
      ],
    };
    this.rooms.seedRoom(this.room);

    ({ sdk: this.sdk, FakeLivekitRoom: this.FakeLivekitRoom } = buildFakeSdk());
    this.sdkLoads = 0;
    setLivekitSdkLoaderForTesting(async () => {
      this.sdkLoads++;
      return this.sdk;
    });
    setLivekitReconnectDelaysForTesting([0, 0, 0]);

    this.joinRequests = 0;
    this.leaveRequests = 0;
    pretender.post("/voice/rooms/1/join", () => {
      this.joinRequests++;
      return response({
        transport: "livekit",
        livekit: { url: "wss://sfu.example.com", token: "token-1" },
        room: JSON.parse(JSON.stringify(this.room)),
      });
    });
    pretender.post("/voice/rooms/1/toggle_mute", () => response({}));
    pretender.post("/voice/rooms/1/signal", () => response({}));
    this.stateRequests = [];
    pretender.post("/voice/rooms/1/state", (request) => {
      this.stateRequests.push(
        Object.fromEntries(new URLSearchParams(request.requestBody))
      );
      return response({});
    });
    pretender.delete("/voice/rooms/1/leave", () => {
      this.leaveRequests++;
      return response({});
    });

    this.originalRTCPeerConnection = globalThis.RTCPeerConnection;
    this.originalMediaStream = globalThis.MediaStream;
    FakeRTCPeerConnection.created = 0;
    globalThis.RTCPeerConnection = FakeRTCPeerConnection;
    globalThis.MediaStream = class {
      constructor(tracks = []) {
        this.tracks = [...tracks];
      }

      getTracks() {
        return [...this.tracks];
      }

      getAudioTracks() {
        return this.tracks.filter((track) => track.kind === "audio");
      }

      getVideoTracks() {
        return this.tracks.filter((track) => track.kind === "video");
      }

      addTrack(track) {
        this.tracks.push(track);
      }

      removeTrack(track) {
        this.tracks = this.tracks.filter((existing) => existing !== track);
      }
    };

    const rawTrack = createFakeTrack("raw-track");
    this.rawTrack = rawTrack;
    this.rawStream = createFakeStream("raw-stream", rawTrack);
    this.processedTrack = createFakeTrack("processed-track");
    this.processedStream = createFakeStream(
      "processed-stream",
      this.processedTrack
    );
    this.audioEnvironment = installFakeAudioEnvironment({
      rawStream: this.rawStream,
      processedStream: this.processedStream,
    });

    // Video capture fakes on top of the audio environment: getUserMedia with
    // video constraints returns the fake camera, getDisplayMedia the fake
    // screen. audioEnvironment.restore() puts getUserMedia back.
    this.cameraTrack = createFakeTrack("camera-track", "video");
    this.cameraStream = createFakeMediaStream("camera-stream", [
      this.cameraTrack,
    ]);
    this.screenVideoTrack = createFakeTrack("screen-video-track", "video");
    this.screenAudioTrack = createFakeTrack("screen-audio-track", "audio");
    this.screenStream = createFakeMediaStream("screen-stream", [
      this.screenVideoTrack,
      this.screenAudioTrack,
    ]);
    const audioGetUserMedia = navigator.mediaDevices.getUserMedia;
    navigator.mediaDevices.getUserMedia = async (constraints) =>
      constraints?.video ? this.cameraStream : audioGetUserMedia(constraints);
    this.originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia;
    navigator.mediaDevices.getDisplayMedia = async () => this.screenStream;

    this.subject = this.owner.lookup("service:voice-webrtc");
  });

  hooks.afterEach(function () {
    this.subject?.leave({ id: 1 }, { keepLocalStream: true });
    this.keyValueStore.remove(this.cameraPreferenceKey);

    setPeerTimingForTesting(null);
    setLivekitSdkLoaderForTesting(null);
    setLivekitReconnectDelaysForTesting(null);
    localStorage.removeItem("voice:noise-suppression");
    localStorage.removeItem("voice:noise-suppression-mode");
    this.audioEnvironment.restore();
    if (this.originalGetDisplayMedia) {
      navigator.mediaDevices.getDisplayMedia = this.originalGetDisplayMedia;
    } else {
      delete navigator.mediaDevices.getDisplayMedia;
    }
    globalThis.RTCPeerConnection = this.originalRTCPeerConnection;
    globalThis.MediaStream = this.originalMediaStream;
  });

  test("mesh rooms never load the LiveKit SDK", async function (assert) {
    pretender.post("/voice/rooms/1/join", () =>
      response({
        transport: "mesh",
        room: JSON.parse(JSON.stringify(this.room)),
      })
    );

    await this.subject.join(this.room);
    await wait(50);

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "connected",
      "the mesh join completes normally"
    );
    assert.strictEqual(
      this.sdkLoads,
      0,
      "the SDK loader is never invoked for a mesh room"
    );
    assert.strictEqual(
      this.FakeLivekitRoom.instances.length,
      0,
      "no LiveKit room object is ever constructed"
    );
  });

  test("livekit join connects to the SFU and publishes the microphone", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    assert.strictEqual(this.sdkLoads, 1, "loads the SDK once");
    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "connected",
      "the room reaches the connected state"
    );

    const lkRoom = this.FakeLivekitRoom.instances[0];
    assert.deepEqual(
      lkRoom.options,
      { adaptiveStream: false, dynacast: true },
      "constructs the room with adaptiveStream off and dynacast on"
    );
    assert.deepEqual(
      lkRoom.connectCalls,
      [{ url: "wss://sfu.example.com", token: "token-1" }],
      "connects with the url and token from the join response"
    );

    const publication = lkRoom.localParticipant.published[0];
    assert.strictEqual(
      publication.track.mediaStreamTrack,
      this.rawTrack,
      "publishes the local microphone track"
    );
    assert.deepEqual(
      publication.options,
      { source: "microphone", dtx: true, red: true },
      "publishes as a DTX+RED microphone source"
    );

    assert.strictEqual(
      FakeRTCPeerConnection.created,
      0,
      "never creates mesh peer connections for a livekit room"
    );
  });

  test("joining an active room does not create a second LiveKit session", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    await this.subject.join(this.room);

    assert.strictEqual(
      this.joinRequests,
      1,
      "does not request a second room join"
    );
    assert.strictEqual(
      this.FakeLivekitRoom.instances.length,
      1,
      "does not create a second media session with the same identity"
    );
  });

  test("noise suppression toggle replaces the published audio track", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    await this.subject.setNoiseSuppressionMode("ai:dtln");

    const publication =
      this.FakeLivekitRoom.instances[0].localParticipant.published[0];
    assert.deepEqual(
      publication.track.replaceCalls,
      [this.processedTrack],
      "moves the live publication onto the processed track"
    );
  });

  test("subscribed tracks land in the remote registry under numeric user ids", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    // Screen audio is watch-gated; the mic below is not.
    this.subject.setWatching(1, true);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    const micTrack = createFakeTrack("remote-mic-2");
    lkRoom.emit(
      "trackSubscribed",
      { kind: "audio", mediaStreamTrack: micTrack, mediaStream: null },
      { source: "microphone" },
      { identity: "2" }
    );
    await wait(10);

    const stream = this.subject.remoteStreamFor(1, 2);
    assert.true(!!stream, "registers a stream keyed by the numeric user id");
    assert.deepEqual(
      stream.getTracks().map((track) => track.id),
      ["remote-mic-2"],
      "the stream carries the subscribed microphone track"
    );

    const screenAudioTrack = createFakeTrack("remote-screen-audio-2");
    lkRoom.emit(
      "trackSubscribed",
      {
        kind: "audio",
        mediaStreamTrack: screenAudioTrack,
        mediaStream: null,
      },
      { source: "screen_share_audio" },
      { identity: "2" }
    );
    await wait(10);

    assert.deepEqual(
      this.subject.remoteScreenAudioStreams.map(
        (screenStream) => screenStream.getTracks()[0].id
      ),
      ["remote-screen-audio-2"],
      "a screen-share-audio source keeps the bare-track convention and lands in the screen audio registry"
    );
    assert.deepEqual(
      this.subject
        .remoteStreamFor(1, 2)
        .getTracks()
        .map((track) => track.id),
      ["remote-mic-2"],
      "screen audio never clobbers the participant's voice stream"
    );
  });

  test("a participant expelled from the roster loses their media", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    const subscribedCalls = [];
    lkRoom.remoteParticipants.set("2", {
      identity: "2",
      trackPublications: new Map([
        [
          "mic-sid",
          {
            setSubscribed(value) {
              subscribedCalls.push(value);
            },
          },
        ],
      ]),
    });

    lkRoom.emit(
      "trackSubscribed",
      {
        kind: "audio",
        mediaStreamTrack: createFakeTrack("remote-mic-2"),
        mediaStream: null,
      },
      { source: "microphone" },
      { identity: "2" }
    );
    await wait(10);

    assert.true(!!this.subject.remoteStreamFor(1, 2), "media is registered");

    this.rooms.emit(1, {
      type: "participants",
      participants: [{ id: this.currentUser.id, role: "participant" }],
    });
    await wait(20);

    assert.strictEqual(
      this.subject.remoteStreamFor(1, 2),
      undefined,
      "the registry entry is dropped when the roster no longer lists the user"
    );
    assert.deepEqual(
      subscribedCalls,
      [false],
      "their SFU subscriptions are dropped too"
    );
  });

  test("a duplicate-identity disconnect tears down locally without DELETE /leave", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    lkRoom.emit("disconnected", this.sdk.DisconnectReason.DUPLICATE_IDENTITY);
    await wait(50);

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "idle",
      "the local call state is torn down"
    );
    assert.strictEqual(
      this.toasts.defaults.length,
      1,
      "the user is told the call moved to another tab"
    );

    // The deferred room teardown runs 500ms after leave.
    await wait(600);

    assert.strictEqual(
      this.leaveRequests,
      0,
      "no DELETE /leave is issued — the presence/session now belongs to the newer tab"
    );
    assert.strictEqual(
      this.FakeLivekitRoom.instances.length,
      1,
      "no reconnection is attempted"
    );
  });

  test("a connect failure cleans up server presence and fails the join", async function (assert) {
    this.FakeLivekitRoom.connectErrors.push(new Error("firewall"));

    await this.subject.join(this.room);
    await wait(50);

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "idle",
      "the join fails instead of leaving a half-joined room"
    );
    assert.strictEqual(
      this.leaveRequests,
      1,
      "tells the server we left so the roster doesn't carry a ghost"
    );
    assert.strictEqual(
      this.toasts.errors.length,
      1,
      "shows the unreachable-voice-server toast"
    );
  });

  test("a terminal disconnect reconnects with a freshly minted token", async function (assert) {
    let mintCalls = 0;
    pretender.post("/voice/rooms/1/livekit_token", () => {
      mintCalls++;
      return response({ url: "wss://sfu.example.com", token: "token-2" });
    });

    await this.subject.join(this.room);
    await wait(50);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    lkRoom.emit("disconnected", this.sdk.DisconnectReason.SERVER_SHUTDOWN);
    await waitUntil(() => this.FakeLivekitRoom.instances.length === 2);
    await wait(20);

    assert.strictEqual(mintCalls, 1, "mints one fresh token");

    const reconnectedRoom = this.FakeLivekitRoom.instances[1];
    assert.deepEqual(
      reconnectedRoom.connectCalls,
      [{ url: "wss://sfu.example.com", token: "token-2" }],
      "reconnects with the newly minted token"
    );
    assert.strictEqual(
      reconnectedRoom.localParticipant.published.length,
      1,
      "republishes the microphone after reconnecting"
    );
    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "connected",
      "the call stays up"
    );
    assert.strictEqual(this.leaveRequests, 0, "never leaves the room");
  });

  test("the reconnect ladder stops immediately on 410 Gone", async function (assert) {
    let mintCalls = 0;
    pretender.post("/voice/rooms/1/livekit_token", () => {
      mintCalls++;
      return response(410, { errors: ["room instance ended"] });
    });

    await this.subject.join(this.room);
    await wait(50);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    lkRoom.emit("disconnected", this.sdk.DisconnectReason.SERVER_SHUTDOWN);
    await waitUntil(() => this.subject.connectionStateFor(1) === "idle");
    await wait(20);

    assert.strictEqual(
      mintCalls,
      1,
      "gives up after the first 410 instead of burning the remaining attempts"
    );
    assert.strictEqual(
      this.FakeLivekitRoom.instances.length,
      1,
      "never constructs a new SFU connection"
    );
    assert.strictEqual(
      this.leaveRequests,
      1,
      "leaves cleanly so stale presence and session rows get closed"
    );
    assert.strictEqual(this.toasts.defaults.length, 1, "offers a rejoin toast");
  });

  test("an exhausted reconnect ladder leaves the room", async function (assert) {
    let mintCalls = 0;
    pretender.post("/voice/rooms/1/livekit_token", () => {
      mintCalls++;
      return response({ url: "wss://sfu.example.com", token: "token-2" });
    });
    await this.subject.join(this.room);
    await wait(50);

    this.FakeLivekitRoom.connectErrors.push(
      new Error("down"),
      new Error("down"),
      new Error("down")
    );

    const lkRoom = this.FakeLivekitRoom.instances[0];
    lkRoom.emit("disconnected", this.sdk.DisconnectReason.SERVER_SHUTDOWN);
    await waitUntil(() => this.subject.connectionStateFor(1) === "idle", 1000);
    await wait(20);

    assert.strictEqual(mintCalls, 3, "retries three times with fresh tokens");
    assert.strictEqual(
      this.leaveRequests,
      1,
      "leaves the room after exhausting the ladder"
    );
    assert.strictEqual(
      this.toasts.errors.length,
      1,
      "tells the user the connection could not be recovered"
    );
  });

  test("a remembered camera publishes after the LiveKit call becomes visible", async function (assert) {
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    await this.subject.join(this.room);
    this.subject.setWatching(1, true);
    await waitUntil(() =>
      this.stateRequests.some(({ video }) => video === "true")
    );

    const lkRoom = this.FakeLivekitRoom.instances[0];
    const publication = lkRoom.localParticipant.published.find(
      ({ track }) => track.mediaStreamTrack === this.cameraTrack
    );

    assert.notStrictEqual(
      publication,
      undefined,
      "publishes the remembered camera track"
    );
    assert.deepEqual(
      this.stateRequests.at(-1),
      { video: "true", screen: "false" },
      "broadcasts the restored camera state"
    );
  });

  test("toggleCamera publishes a simulcast camera track and broadcasts state", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    await this.subject.toggleCamera();
    await wait(20);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    const publication = lkRoom.localParticipant.published[1];
    assert.strictEqual(
      publication.track.mediaStreamTrack,
      this.cameraTrack,
      "publishes the camera track"
    );
    assert.deepEqual(
      publication.options,
      {
        source: "camera",
        simulcast: true,
        videoEncoding: { maxBitrate: 1_200_000, maxFramerate: 24 },
      },
      "publishes with simulcast and the camera encoding preset"
    );
    assert.deepEqual(
      this.stateRequests.at(-1),
      { video: "true", screen: "false" },
      "broadcasts the video state exactly like mesh does"
    );

    await this.subject.toggleCamera();
    await wait(20);

    assert.deepEqual(
      lkRoom.localParticipant.unpublishCalls.map((call) => [
        call.track.mediaStreamTrack.id,
        call.stopOnUnpublish,
      ]),
      [["camera-track", false]],
      "unpublishes the camera without stopping the service-owned track"
    );
    assert.strictEqual(
      lkRoom.localParticipant.published.length,
      1,
      "only the microphone remains published"
    );
    assert.deepEqual(
      this.stateRequests.at(-1),
      { video: "false", screen: "false" },
      "broadcasts the stopped state"
    );
    assert.strictEqual(
      FakeRTCPeerConnection.created,
      0,
      "video never creates mesh peer connections"
    );
  });

  test("toggleScreenShare publishes the screen track and content audio", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    await this.subject.toggleScreenShare();
    await wait(20);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    const videoPublication = lkRoom.localParticipant.published[1];
    assert.strictEqual(
      videoPublication.track.mediaStreamTrack,
      this.screenVideoTrack,
      "publishes the screen video track"
    );
    assert.deepEqual(
      videoPublication.options,
      {
        source: "screen_share",
        simulcast: true,
        screenShareEncoding: { maxBitrate: 2_500_000, maxFramerate: 15 },
      },
      "publishes with the screenshare encoding preset"
    );

    const audioPublication = lkRoom.localParticipant.published[2];
    assert.strictEqual(
      audioPublication.track.mediaStreamTrack,
      this.screenAudioTrack,
      "publishes the screen audio track"
    );
    assert.deepEqual(
      audioPublication.options,
      { source: "screen_share_audio", dtx: false, audioBitrate: 128_000 },
      "publishes content audio without DTX and with the higher Opus ceiling"
    );
    assert.deepEqual(
      this.stateRequests.at(-1),
      { video: "false", screen: "true" },
      "broadcasts the screen-sharing state"
    );

    await this.subject.toggleScreenShare();
    await wait(20);

    assert.strictEqual(
      lkRoom.localParticipant.published.length,
      1,
      "stopping the share unpublishes both screen tracks"
    );
    assert.deepEqual(
      lkRoom.localParticipant.unpublishCalls.map(
        (call) => call.stopOnUnpublish
      ),
      [false, false],
      "the service keeps ownership of the capture tracks"
    );
  });

  test("setWatching gates remote video subscriptions on the subscriber side", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    const micPublication = createFakeRemotePublication("microphone", "audio");
    const cameraPublication = createFakeRemotePublication("camera", "video");
    const screenAudioPublication = createFakeRemotePublication(
      "screen_share_audio",
      "audio"
    );
    const publications = new Map([
      ["mic-sid", micPublication],
      ["camera-sid", cameraPublication],
      ["screen-audio-sid", screenAudioPublication],
    ]);
    lkRoom.remoteParticipants.set("2", {
      identity: "2",
      trackPublications: publications,
    });

    this.subject.setWatching(1, true);

    assert.deepEqual(
      cameraPublication.subscribedCalls,
      [true],
      "watching subscribes the camera"
    );
    assert.deepEqual(
      screenAudioPublication.subscribedCalls,
      [true],
      "watching subscribes screen audio"
    );

    this.subject.setWatching(1, false);

    assert.deepEqual(
      cameraPublication.subscribedCalls,
      [true, false],
      "leaving the page unsubscribes the camera"
    );
    assert.deepEqual(
      screenAudioPublication.subscribedCalls,
      [true, false],
      "leaving the page unsubscribes screen audio"
    );
    assert.deepEqual(
      micPublication.subscribedCalls,
      [],
      "microphone subscriptions are never gated"
    );

    const latePublication = createFakeRemotePublication("camera", "video");
    publications.set("late-camera-sid", latePublication);
    lkRoom.emit("trackPublished", latePublication, { identity: "2" });

    assert.deepEqual(
      latePublication.subscribedCalls,
      [false],
      "a camera published while not watching starts unsubscribed"
    );

    this.subject.setWatching(1, true);

    assert.deepEqual(
      latePublication.subscribedCalls,
      [false, true],
      "watching again picks the late publication up"
    );
  });

  test("subscriptions pick simulcast layers from the publisher count", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    this.subject.setWatching(1, true);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    const cameraPublication = createFakeRemotePublication("camera", "video");
    const screenPublication = createFakeRemotePublication(
      "screen_share",
      "video"
    );
    lkRoom.remoteParticipants.set("2", {
      identity: "2",
      trackPublications: new Map([
        ["camera-sid", cameraPublication],
        ["screen-sid", screenPublication],
      ]),
    });

    lkRoom.emit(
      "trackSubscribed",
      {
        kind: "video",
        mediaStreamTrack: createFakeTrack("remote-camera-2", "video"),
        mediaStream: null,
      },
      cameraPublication,
      { identity: "2" }
    );
    lkRoom.emit(
      "trackSubscribed",
      {
        kind: "video",
        mediaStreamTrack: createFakeTrack("remote-screen-2", "video"),
        mediaStream: null,
      },
      screenPublication,
      { identity: "2" }
    );
    await wait(10);

    assert.deepEqual(
      cameraPublication.qualityCalls,
      [1],
      "cameras subscribe at the MEDIUM layer in small rooms"
    );
    assert.deepEqual(
      screenPublication.qualityCalls,
      [2],
      "screenshares subscribe at the HIGH layer"
    );

    const participants = [{ id: this.currentUser.id, role: "participant" }];
    for (let id = 2; id <= 8; id++) {
      participants.push({ id, role: "participant", is_video_on: true });
    }
    this.rooms.emit(1, { type: "participants", participants });
    await wait(20);

    assert.strictEqual(
      cameraPublication.qualityCalls.at(-1),
      0,
      "more than six publishers drops cameras to the LOW layer"
    );
    assert.strictEqual(
      screenPublication.qualityCalls.at(-1),
      2,
      "screenshares stay on the HIGH layer regardless of room size"
    );
  });

  test("a stage promotion publishes the microphone without reconnecting", async function (assert) {
    this.room.room_type = "stage";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "listener" },
      { id: 2, role: "moderator" },
    ];

    await this.subject.join(this.room);
    await wait(50);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    assert.strictEqual(
      lkRoom.localParticipant.published.length,
      0,
      "a stage listener publishes nothing"
    );

    this.rooms.emit(1, {
      type: "role_change",
      user_id: this.currentUser.id,
      role: "speaker",
    });
    await waitUntil(() => lkRoom.localParticipant.published.length === 1);

    const publication = lkRoom.localParticipant.published[0];
    assert.strictEqual(
      publication.track.mediaStreamTrack,
      this.rawTrack,
      "publishes the freshly acquired microphone"
    );
    assert.deepEqual(
      publication.options,
      { source: "microphone", dtx: true, red: true },
      "publishes it as a regular microphone source"
    );
    assert.strictEqual(
      this.FakeLivekitRoom.instances.length,
      1,
      "the promotion never reconnects the media session"
    );
  });

  test("a stage demotion releases the microphone publication", async function (assert) {
    this.room.room_type = "stage";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "moderator" },
    ];

    await this.subject.join(this.room);
    await wait(50);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    assert.strictEqual(
      lkRoom.localParticipant.published.length,
      1,
      "a speaker starts out publishing the microphone"
    );

    this.rooms.emit(1, {
      type: "role_change",
      user_id: this.currentUser.id,
      role: "listener",
    });
    await waitUntil(() => lkRoom.localParticipant.published.length === 0);

    assert.deepEqual(
      lkRoom.localParticipant.unpublishCalls.map(
        (call) => call.stopOnUnpublish
      ),
      [false],
      "the microphone is unpublished without the SDK stopping the track"
    );
    assert.strictEqual(
      this.FakeLivekitRoom.instances.length,
      1,
      "the demotion never reconnects the media session"
    );
  });

  test("a stage demotion stops a live camera along with the microphone", async function (assert) {
    this.room.room_type = "stage";
    this.room.video_enabled = true;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "moderator" },
    ];

    await this.subject.join(this.room);
    await wait(50);
    await this.subject.toggleCamera();
    await wait(20);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    assert.deepEqual(
      lkRoom.localParticipant.published.map(
        (publication) => publication.source
      ),
      ["microphone", "camera"],
      "a publishing speaker holds both the microphone and camera publications"
    );

    this.rooms.emit(1, {
      type: "role_change",
      user_id: this.currentUser.id,
      role: "participant",
    });
    await waitUntil(() => lkRoom.localParticipant.published.length === 0);

    assert.false(
      lkRoom.localParticipant.published.some(
        (publication) => publication.source === "camera"
      ),
      "the camera publication is unpublished on demotion"
    );
    assert.strictEqual(
      this.subject.localVideoKind,
      null,
      "the local video capture is fully stopped"
    );
    assert.strictEqual(
      this.FakeLivekitRoom.instances.length,
      1,
      "the demotion never reconnects the media session"
    );
  });

  test("a ladder reconnect republishes the live camera", async function (assert) {
    pretender.post("/voice/rooms/1/livekit_token", () =>
      response({ url: "wss://sfu.example.com", token: "token-2" })
    );

    await this.subject.join(this.room);
    await wait(50);
    await this.subject.toggleCamera();
    await wait(20);

    const lkRoom = this.FakeLivekitRoom.instances[0];
    lkRoom.emit("disconnected", this.sdk.DisconnectReason.SERVER_SHUTDOWN);
    await waitUntil(() => this.FakeLivekitRoom.instances.length === 2);
    await wait(20);

    const reconnectedRoom = this.FakeLivekitRoom.instances[1];
    assert.deepEqual(
      reconnectedRoom.localParticipant.published.map(
        (publication) => publication.source
      ),
      ["microphone", "camera"],
      "the new connection carries both the microphone and the camera"
    );
    assert.strictEqual(
      reconnectedRoom.localParticipant.published[1].track.mediaStreamTrack,
      this.cameraTrack,
      "the same capture track is republished"
    );
  });
});
