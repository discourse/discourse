import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Site from "discourse/models/site";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { setPeerTimingForTesting } from "discourse/plugins/voice/discourse/lib/voice/peer-manager";

// Park the service's wall-clock timers far outside any test's window so a
// CPU-starved run can't have a fallback offer, peer restart, or stuck-"new"
// rescue fire mid-test (QUnit shuffles test order every run, so an unexpected
// firing poisons whichever test happens to be running). Tests that exercise
// one of these timers override just that delay with something small enough to
// await deterministically.
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

class ToastsStub extends Service {
  errors = [];

  error(options) {
    this.errors.push(options);
  }

  success() {}
  default() {}
}

class FakeRTCPeerConnection {
  static created = 0;
  static instances = [];

  signalingState = "stable";
  connectionState = "new";
  iceConnectionState = "new";
  iceGatheringState = "new";
  localDescription = null;
  remoteDescription = null;
  senders = [];
  transceivers = [];

  addedCandidates = [];

  constructor() {
    FakeRTCPeerConnection.created++;
    FakeRTCPeerConnection.instances.push(this);
  }

  addTrack(track) {
    const sender = {
      track,
      replaceCalls: [],
      async replaceTrack(newTrack) {
        this.track = newTrack;
        this.replaceCalls.push(newTrack);
      },
    };

    this.senders.push(sender);
    return sender;
  }

  addTransceiver(kind, options) {
    const receiverTrack = {
      id: `${kind}-receiver-${this.transceivers.length + 1}`,
      kind,
    };
    const sender = {
      track: null,
      replaceCalls: [],
      async replaceTrack(newTrack) {
        this.track = newTrack;
        this.replaceCalls.push(newTrack);
      },
      getParameters() {
        return { encodings: [{}] };
      },
      async setParameters() {},
    };

    const transceiver = {
      direction: options?.direction ?? "sendrecv",
      sender,
      receiver: { track: receiverTrack },
    };

    this.transceivers.push(transceiver);
    this.senders.push(sender);
    return transceiver;
  }

  getTransceivers() {
    return this.transceivers;
  }

  getSenders() {
    return this.senders;
  }

  async createOffer() {
    return { type: "offer", sdp: "fake-offer" };
  }

  async createAnswer() {
    return { type: "answer", sdp: "fake-answer" };
  }

  async setLocalDescription(description) {
    this.localDescription = description;

    if (description?.type === "offer") {
      this.signalingState = "have-local-offer";
    } else if (
      description?.type === "answer" ||
      description?.type === "rollback"
    ) {
      this.signalingState = "stable";
    }
  }

  async setRemoteDescription(description) {
    this.remoteDescription = description;

    if (description?.type === "offer") {
      this.signalingState = "have-remote-offer";
    } else if (description?.type === "answer") {
      this.signalingState = "stable";
    }
  }

  async addIceCandidate(candidate) {
    this.addedCandidates.push(candidate);
  }

  close() {
    this.connectionState = "closed";
  }
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

function signalPayloadFrom(request) {
  const params = new URLSearchParams(request.requestBody);

  return {
    recipientId: Number(params.get("payload[recipient_id]")),
    type: params.get("payload[type]"),
    sdp: params.get("payload[sdp]"),
  };
}

// Flattens a signal POST into individual { recipientId, type, sdp } entries,
// tolerating the three payload shapes the signaling layer emits: a single
// event, a single recipient with multiple coalesced events, and multiple
// recipients. Use when signals to the same peer may land in one HTTP batch.
function signalsFrom(request) {
  const params = new URLSearchParams(request.requestBody);
  const get = (key) => params.get(key);

  if (get("payload[messages][0][recipient_id]")) {
    const signals = [];
    for (let m = 0; get(`payload[messages][${m}][recipient_id]`); m++) {
      const recipientId = Number(get(`payload[messages][${m}][recipient_id]`));
      for (let e = 0; get(`payload[messages][${m}][events][${e}][type]`); e++) {
        signals.push({
          recipientId,
          type: get(`payload[messages][${m}][events][${e}][type]`),
          sdp: get(`payload[messages][${m}][events][${e}][sdp]`),
        });
      }
    }
    return signals;
  }

  const recipientId = Number(get("payload[recipient_id]"));

  if (get("payload[events][0][type]")) {
    const signals = [];
    for (let e = 0; get(`payload[events][${e}][type]`); e++) {
      signals.push({
        recipientId,
        type: get(`payload[events][${e}][type]`),
        sdp: get(`payload[events][${e}][sdp]`),
      });
    }
    return signals;
  }

  return [
    { recipientId, type: get("payload[type]"), sdp: get("payload[sdp]") },
  ];
}

function deferred() {
  let resolve;
  let reject;

  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });

  return { promise, resolve, reject };
}

function createFakeTrack(id, kind = "audio") {
  return {
    id,
    kind,
    enabled: true,
    stop() {},
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

function installFakeAudioEnvironment({ rawStream, processedStream }) {
  const sourceStreams = [];
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

    createMediaStreamSource(stream) {
      sourceStreams.push(stream);

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
    sourceStreams,
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

module("Voice | Unit | Service | voice-webrtc", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    setPeerTimingForTesting(SAFE_PEER_TIMING);
    this.currentUser = logIn(this.owner);
    this.keyValueStore = this.owner.lookup("service:key-value-store");
    this.cameraPreferenceKey = `voice-camera-enabled-${this.currentUser.id}`;
    this.keyValueStore.remove(this.cameraPreferenceKey);
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.siteSettings.voice_auto_status_enabled = true;
    localStorage.removeItem("voice:noise-suppression");
    localStorage.removeItem("voice:noise-suppression-mode");

    this.owner.unregister("service:voice-rooms");
    this.owner.register("service:voice-rooms", VoiceRoomsStub);
    this.owner.unregister("service:toasts");
    this.owner.register("service:toasts", ToastsStub);

    this.rooms = this.owner.lookup("service:voice-rooms");
    this.room = {
      id: 1,
      name: "Stage",
      room_type: "stage",
      membership: { role_name: "listener" },
      active_participants: [
        { id: this.currentUser.id, role: "listener" },
        { id: 2, role: "speaker" },
      ],
    };
    this.rooms.seedRoom(this.room);

    pretender.post("/voice/rooms/1/join", () =>
      response({
        participant_session_id: "session-abc",
        room: JSON.parse(JSON.stringify(this.room)),
      })
    );
    pretender.post("/voice/rooms/1/signal", () => response({}));
    pretender.post("/voice/rooms/1/toggle_mute", () => response({}));
    pretender.delete("/voice/rooms/1/leave", () => response({}));

    this.originalRTCPeerConnection = globalThis.RTCPeerConnection;
    this.originalRTCIceCandidate = globalThis.RTCIceCandidate;
    this.originalRTCSessionDescription = globalThis.RTCSessionDescription;
    this.originalMediaStream = globalThis.MediaStream;

    FakeRTCPeerConnection.created = 0;
    FakeRTCPeerConnection.instances = [];
    globalThis.RTCPeerConnection = FakeRTCPeerConnection;
    globalThis.MediaStream = class {
      static counter = 0;

      constructor(tracks = []) {
        this.id = `fake-media-stream-${++globalThis.MediaStream.counter}`;
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
    globalThis.RTCIceCandidate = class {
      constructor(candidate) {
        Object.assign(this, candidate);
      }
    };
    globalThis.RTCSessionDescription = class {
      constructor(description) {
        Object.assign(this, description);
      }
    };

    this.subject = this.owner.lookup("service:voice-webrtc");
  });

  hooks.afterEach(function () {
    this.subject?.leave({ id: 1 }, { keepLocalStream: true });
    this.keyValueStore.remove(this.cameraPreferenceKey);

    setPeerTimingForTesting(null);
    globalThis.RTCPeerConnection = this.originalRTCPeerConnection;
    globalThis.RTCIceCandidate = this.originalRTCIceCandidate;
    globalThis.RTCSessionDescription = this.originalRTCSessionDescription;
    globalThis.MediaStream = this.originalMediaStream;
  });

  test("ICE configuration defaults to no servers and policy 'all' before any join", function (assert) {
    assert.deepEqual(this.subject.iceServers, []);
    assert.strictEqual(this.subject.iceTransportPolicy, "all");
  });

  test("ICE configuration comes from the join response", async function (assert) {
    const servers = [
      { urls: "stun:stun.example.com:3478" },
      {
        urls: "turn:turn.example.com:3478",
        username: "1750000000:1",
        credential: "hmac-credential",
      },
    ];

    pretender.post("/voice/rooms/1/join", () =>
      response({
        room: JSON.parse(JSON.stringify(this.room)),
        ice: { servers, transport_policy: "relay" },
      })
    );

    await this.subject.join(this.room);

    assert.deepEqual(this.subject.iceServers, servers);
    assert.strictEqual(this.subject.iceTransportPolicy, "relay");
  });

  test("ICE configuration survives a join response without an ice payload", async function (assert) {
    const servers = [{ urls: "stun:stun.example.com:3478" }];

    pretender.post("/voice/rooms/1/join", () =>
      response({
        room: JSON.parse(JSON.stringify(this.room)),
        ice: { servers, transport_policy: "all" },
      })
    );

    await this.subject.join(this.room);
    this.subject.leave(this.room, { keepLocalStream: true });

    pretender.post("/voice/rooms/1/join", () =>
      response({ room: JSON.parse(JSON.stringify(this.room)) })
    );

    await this.subject.join(this.room);

    assert.deepEqual(this.subject.iceServers, servers);
    assert.strictEqual(this.subject.iceTransportPolicy, "all");
  });

  test("ignores stale signals after a participant has left the room", async function (assert) {
    await this.subject.join(this.room);
    await wait(50);

    assert.strictEqual(
      FakeRTCPeerConnection.created,
      1,
      "creates the initial peer for the active speaker"
    );

    this.rooms.emit(1, {
      type: "participants",
      participants: [{ id: this.currentUser.id, role: "listener" }],
    });
    await wait(10);

    this.rooms.emit(1, {
      type: "signal",
      sender_id: 2,
      data: {
        type: "candidate",
        candidate: {
          candidate: "candidate:1 1 UDP 2122252543 127.0.0.1 3478 typ host",
          sdpMid: "0",
          sdpMLineIndex: 0,
        },
      },
    });
    await wait(10);

    assert.strictEqual(
      FakeRTCPeerConnection.created,
      1,
      "does not recreate a peer from a delayed signal after the participant left"
    );
  });

  test("leave cancels a pending join before the late response can activate the room", async function (assert) {
    assert.timeout(2000);

    const joinResponse = deferred();

    pretender.post("/voice/rooms/1/join", () =>
      joinResponse.promise.then(() =>
        response({
          room: JSON.parse(JSON.stringify(this.room)),
        })
      )
    );

    const join = this.subject.join(this.room);
    await wait(10);

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "connecting",
      "marks the room as connecting while the join is pending"
    );

    this.subject.leave({ id: 1 }, { keepLocalStream: true });

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "idle",
      "returns to idle immediately after leaving"
    );

    joinResponse.resolve();
    await join;
    await wait(10);

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "idle",
      "keeps the room idle after the late join response arrives"
    );
    assert.strictEqual(
      FakeRTCPeerConnection.created,
      0,
      "does not create peers for a canceled join"
    );
  });

  test("join uses the latest participant list when more users join during connect", async function (assert) {
    assert.timeout(2000);

    const joinResponse = deferred();
    const staleRoom = {
      ...this.room,
      active_participants: [{ id: this.currentUser.id, role: "listener" }],
    };

    pretender.post("/voice/rooms/1/join", () =>
      joinResponse.promise.then(() =>
        response({
          room: JSON.parse(JSON.stringify(staleRoom)),
        })
      )
    );

    const join = this.subject.join(this.room);
    await wait(10);

    this.rooms.emit(1, {
      type: "participants",
      participants: [
        { id: this.currentUser.id, role: "listener" },
        { id: 2, role: "speaker" },
        { id: 30, role: "speaker" },
      ],
    });

    joinResponse.resolve();
    await join;
    await wait(10);

    assert.strictEqual(
      FakeRTCPeerConnection.created,
      2,
      "creates peers for participants that joined while the room was still connecting"
    );
  });

  test("join still uses the join response when no newer participant broadcast arrived", async function (assert) {
    const responseRoom = {
      ...this.room,
      active_participants: [
        { id: this.currentUser.id, role: "listener" },
        { id: 2, role: "speaker" },
        { id: 30, role: "speaker" },
      ],
    };

    pretender.post("/voice/rooms/1/join", () =>
      response({
        room: JSON.parse(JSON.stringify(responseRoom)),
      })
    );

    await this.subject.join(this.room);
    await wait(10);

    assert.strictEqual(
      FakeRTCPeerConnection.created,
      2,
      "creates peers for participants only present in the fresher join response"
    );
  });

  test("kicked while connecting cancels the pending join", async function (assert) {
    assert.timeout(2000);

    const joinResponse = deferred();

    pretender.post("/voice/rooms/1/join", () =>
      joinResponse.promise.then(() =>
        response({
          room: JSON.parse(JSON.stringify(this.room)),
        })
      )
    );

    const join = this.subject.join(this.room);
    await wait(10);

    this.rooms.emit(1, { type: "kicked" });
    await wait(10);

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "idle",
      "drops back to idle immediately after the kick"
    );

    joinResponse.resolve();
    await join;
    await wait(10);

    assert.strictEqual(
      this.subject.connectionStateFor(1),
      "idle",
      "stays idle after the late join response arrives"
    );
    assert.strictEqual(
      FakeRTCPeerConnection.created,
      0,
      "does not create peers after a connect-time kick"
    );
  });

  test("join replays queued connect-time signals for existing peers", async function (assert) {
    assert.timeout(2000);

    const joinResponse = deferred();
    let signalRequests = 0;

    pretender.post("/voice/rooms/1/join", () =>
      joinResponse.promise.then(() =>
        response({
          room: JSON.parse(JSON.stringify(this.room)),
        })
      )
    );
    pretender.post("/voice/rooms/1/signal", () => {
      signalRequests++;
      return response({});
    });

    const join = this.subject.join(this.room);
    await wait(10);

    this.rooms.emit(1, {
      type: "signal",
      sender_id: 2,
      data: { type: "offer", sdp: "queued-offer" },
    });

    joinResponse.resolve();
    await join;
    // Wait past the signaling HTTP batch window (200ms); the offer fallback
    // retry is parked far out by SAFE_PEER_TIMING, so a single request proves
    // the answer was sent via the immediate replay rather than the fallback.
    await wait(300);

    assert.strictEqual(
      signalRequests,
      1,
      "sends an answer immediately after join instead of waiting for the fallback retry"
    );
  });

  test("join offers deterministically based on user id to avoid glare", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];

    // Current user id is higher than the existing peer's, so it must NOT
    // offer immediately (that is what caused glare); the lower-id peer owns
    // the immediate offer. A short fallback offer fires only if the peer
    // never offers — shrink its delay so the test can await it.
    setPeerTimingForTesting({ ...SAFE_PEER_TIMING, offerRetryBaseDelayMs: 50 });
    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(signalPayloadFrom(request));
      return response({});
    });

    try {
      await this.subject.join(this.room);
      await wait(50);

      assert.strictEqual(
        signalRequests.length,
        0,
        "does not send an immediate offer when the current user id is higher than the peer id"
      );

      await waitUntil(() => signalRequests.length === 1, 1500);

      assert.deepEqual(
        signalRequests[0],
        { recipientId: 2, type: "offer", sdp: "fake-offer" },
        "sends a fallback offer to the lower-id peer after the short retry delay"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("simultaneous join offers resolve glare by rolling back the lower user id side", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];

    this.currentUser.id = 2;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 50, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(signalPayloadFrom(request));
      return response({});
    });

    try {
      await this.subject.join(this.room);
      await waitUntil(() => signalRequests.length === 1);

      this.rooms.emit(1, {
        type: "signal",
        sender_id: 50,
        data: { type: "offer", sdp: "simultaneous-offer" },
      });
      await waitUntil(() => signalRequests.length === 2);

      const pc = FakeRTCPeerConnection.instances[0];
      assert.deepEqual(
        signalRequests[0],
        { recipientId: 50, type: "offer", sdp: "fake-offer" },
        "sends the initial offer before receiving the competing offer"
      );
      assert.deepEqual(
        signalRequests[1],
        { recipientId: 50, type: "answer", sdp: "fake-answer" },
        "answers the competing offer after rollback"
      );
      assert.strictEqual(
        pc.remoteDescription.sdp,
        "simultaneous-offer",
        "accepts the competing offer after rolling back local offer"
      );
      assert.strictEqual(
        pc.localDescription.type,
        "answer",
        "finishes glare resolution with an answer"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("higher-id peer joining a populated room connects to the lower-id peer without glare", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];

    // The reported regression: a new participant whose id is higher than an
    // already-connected peer's joins the room. With the deterministic
    // offerer the joiner does not offer; it answers the lower-id peer and
    // ends up connected with that peer's audio, without waiting for the 30s
    // connection timeout.
    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(signalPayloadFrom(request));
      return response({});
    });

    try {
      await this.subject.join(this.room);
      await wait(50);

      assert.strictEqual(
        signalRequests.length,
        0,
        "does not send a competing offer that would collide with the peer's"
      );

      const pc = FakeRTCPeerConnection.instances[0];

      // The lower-id peer owns the immediate offer.
      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        data: { type: "offer", sdp: "peer-offer" },
      });
      await waitUntil(() => signalRequests.length === 1, 1500);

      assert.deepEqual(
        signalRequests[0],
        { recipientId: 2, type: "answer", sdp: "fake-answer" },
        "answers the lower-id peer's offer instead of racing it with its own"
      );
      assert.strictEqual(
        pc.signalingState,
        "stable",
        "negotiation completes without leaving a dangling local offer"
      );

      // The peer's audio track arrives and is exposed to the room.
      const remoteTrack = createFakeTrack("peer-2-track");
      const remoteStream = createFakeStream("peer-2-stream", remoteTrack);
      pc.ontrack({ streams: [remoteStream], track: remoteTrack });
      await wait(10);

      assert.true(
        this.subject
          .remoteStreamsFor(1)
          .some((stream) =>
            stream.getTracks().some((track) => track.id === "peer-2-track")
          ),
        "exposes the peer's audio stream after negotiation completes"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("processes a batched signal envelope's events in order", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];

    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(signalPayloadFrom(request));
      return response({});
    });

    try {
      await this.subject.join(this.room);
      await wait(50);

      // One envelope per recipient: the offer plus its trickle candidate ride
      // in a single ordered event batch.
      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        events: [
          { type: "offer", sdp: "peer-offer" },
          {
            type: "candidate",
            candidate: {
              candidate: "candidate:1 1 UDP 2122252543 127.0.0.1 3478 typ host",
              sdpMid: "0",
            },
          },
        ],
      });
      await waitUntil(() => signalRequests.length === 1, 1500);

      assert.deepEqual(
        signalRequests[0],
        { recipientId: 2, type: "answer", sdp: "fake-answer" },
        "answers the offer delivered in a batched envelope"
      );

      const pc = FakeRTCPeerConnection.instances[0];
      await waitUntil(() => pc.addedCandidates.length === 1, 1500);
      assert.strictEqual(
        pc.addedCandidates[0].candidate,
        "candidate:1 1 UDP 2122252543 127.0.0.1 3478 typ host",
        "applies the candidate after the offer it followed in the batch"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  // Answers the remote offer over the first (and only) peer connection and
  // returns that connection once negotiation settled.
  async function answerRemoteOffer(context, senderId) {
    context.rooms.emit(1, {
      type: "signal",
      sender_id: senderId,
      data: { type: "offer", sdp: `peer-${senderId}-offer` },
    });
    await waitUntil(() => FakeRTCPeerConnection.instances.length >= 1, 1500);
    const pc = FakeRTCPeerConnection.instances[0];
    await waitUntil(
      () => pc.remoteDescription && pc.signalingState === "stable",
      1500
    );
    return pc;
  }

  test("drops a microphone track published by a stage listener", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });

    // A speaker keeps a connection to every listener so they can receive the
    // stage — the exact connection a modified listener client can abuse to
    // attach a microphone track the server would never let it unmute.
    this.room.membership = { role_name: "speaker" };
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "listener" },
    ];

    try {
      await this.subject.join(this.room);
      await wait(50);

      const pc = await answerRemoteOffer(this, 2);

      let stopped = false;
      const remoteTrack = createFakeTrack("listener-mic");
      remoteTrack.stop = () => (stopped = true);
      pc.ontrack({
        streams: [createFakeStream("listener-stream", remoteTrack)],
        track: remoteTrack,
      });
      await wait(10);

      assert.strictEqual(
        this.subject.remoteStreamsFor(1).length,
        0,
        "audio from a role that cannot publish is never registered or played"
      );
      assert.true(stopped, "the disallowed track is stopped");
    } finally {
      audioEnvironment.restore();
    }
  });

  test("plays a stage speaker's microphone and keeps a listener's transceivers receive-only", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });

    // The default room: current user is a listener, user 2 is a speaker.
    try {
      await this.subject.join(this.room);
      await wait(50);

      const pc = await answerRemoteOffer(this, 2);

      assert.true(
        pc.transceivers.every(
          (transceiver) => transceiver.direction === "recvonly"
        ),
        "a listener's pre-negotiated transceivers never advertise sending"
      );

      const remoteTrack = createFakeTrack("speaker-mic");
      pc.ontrack({
        streams: [createFakeStream("speaker-stream", remoteTrack)],
        track: remoteTrack,
      });
      await wait(10);

      assert.true(
        this.subject
          .remoteStreamsFor(1)
          .some((stream) =>
            stream.getTracks().some((track) => track.id === "speaker-mic")
          ),
        "audio from a role allowed to publish plays normally"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("drops a video track when the room does not allow video", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });

    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.video_enabled = false;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
    ];

    try {
      await this.subject.join(this.room);
      await wait(50);

      const pc = await answerRemoteOffer(this, 2);

      pc.ontrack({ streams: [], track: createFakeTrack("rogue-cam", "video") });
      await wait(10);

      assert.strictEqual(
        this.subject.remoteStreamsFor(1).length,
        0,
        "video is dropped while the room's media policy disallows it"
      );

      this.room.video_enabled = true;
      pc.ontrack({ streams: [], track: createFakeTrack("real-cam", "video") });
      await wait(10);

      assert.true(
        this.subject
          .remoteStreamsFor(1)
          .some((stream) =>
            stream.getTracks().some((track) => track.id === "real-cam")
          ),
        "video registers once the room allows it"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("a roster refresh drops media from a participant demoted to listener", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });

    this.room.membership = { role_name: "speaker" };
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "speaker" },
    ];

    try {
      await this.subject.join(this.room);
      await wait(50);

      const pc = await answerRemoteOffer(this, 2);

      const remoteTrack = createFakeTrack("peer-2-mic");
      pc.ontrack({
        streams: [createFakeStream("peer-2-stream", remoteTrack)],
        track: remoteTrack,
      });
      await wait(10);

      assert.strictEqual(
        this.subject.remoteStreamsFor(1).length,
        1,
        "the other speaker's audio plays while both hold speaking roles"
      );

      // Demotion arriving as a roster refresh, not a role_change message: the
      // connection survives (a speaker still transmits to the listener) but
      // the demoted participant's registered media must stop immediately.
      this.rooms.emit(1, {
        type: "participants",
        participants: [
          { id: this.currentUser.id, role: "speaker" },
          { id: 2, role: "listener" },
        ],
      });
      await wait(20);

      assert.strictEqual(
        this.subject.remoteStreamsFor(1).length,
        0,
        "the demoted participant's registered media is dropped"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("slow mic, lower-id local user: offer queued during the permission prompt connects via rollback", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];
    const micGranted = deferred();
    navigator.mediaDevices.getUserMedia = () =>
      micGranted.promise.then(() => rawStream);

    // Local user is the designated (lower-id) offerer, but is slow to grant
    // mic access. The higher-id peer's fallback offer arrives while the
    // permission prompt is still open. The immediate offer and the rollback
    // answer to the same peer can land in one HTTP batch, so flatten them.
    this.currentUser.id = 2;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 50, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(...signalsFrom(request));
      return response({});
    });

    try {
      const join = this.subject.join(this.room);
      await wait(20);

      this.rooms.emit(1, {
        type: "signal",
        sender_id: 50,
        data: { type: "offer", sdp: "peer-offer" },
      });
      await wait(20);

      assert.strictEqual(
        FakeRTCPeerConnection.created,
        0,
        "does not create peers or signal before microphone permission is granted"
      );
      assert.strictEqual(
        signalRequests.length,
        0,
        "queues the inbound offer instead of acting on it while connecting"
      );

      micGranted.resolve();
      await join;
      await waitUntil(() => signalRequests.length === 2, 1000);

      const pc = FakeRTCPeerConnection.instances[0];
      assert.deepEqual(
        signalRequests,
        [
          { recipientId: 50, type: "offer", sdp: "fake-offer" },
          { recipientId: 50, type: "answer", sdp: "fake-answer" },
        ],
        "offers immediately on grant, then rolls back and answers the queued offer"
      );
      assert.strictEqual(
        pc.signalingState,
        "stable",
        "ends negotiation in a stable state, not stuck on a dangling offer"
      );

      const remoteTrack = createFakeTrack("peer-50-track");
      const remoteStream = createFakeStream("peer-50-stream", remoteTrack);
      pc.ontrack({ streams: [remoteStream], track: remoteTrack });
      await wait(10);

      assert.true(
        this.subject
          .remoteStreamsFor(1)
          .some((stream) =>
            stream.getTracks().some((track) => track.id === "peer-50-track")
          ),
        "exposes the peer's audio after a slow-permission join"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("slow mic, higher-id local user: queued offer is answered on grant without a competing offer", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];
    const micGranted = deferred();
    navigator.mediaDevices.getUserMedia = () =>
      micGranted.promise.then(() => rawStream);

    // Local user is higher-id, so the lower-id peer owns the offer. That
    // offer lands while the mic prompt is open; on grant the local user
    // must answer it rather than racing it with a fallback offer. Keep the
    // fallback delay small so a broken cancelation would fire well inside
    // the observation window below.
    setPeerTimingForTesting({
      ...SAFE_PEER_TIMING,
      offerRetryBaseDelayMs: 200,
    });
    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(signalPayloadFrom(request));
      return response({});
    });

    try {
      const join = this.subject.join(this.room);
      await wait(20);

      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        data: { type: "offer", sdp: "peer-offer" },
      });
      await wait(20);

      micGranted.resolve();
      await join;
      await waitUntil(() => signalRequests.length === 1, 1000);
      // Wait 3x past the 200ms fallback delay to prove no late competing
      // offer fires.
      await wait(600);

      const pc = FakeRTCPeerConnection.instances[0];
      assert.deepEqual(
        signalRequests,
        [{ recipientId: 2, type: "answer", sdp: "fake-answer" }],
        "answers the queued offer and never sends a competing fallback offer"
      );
      assert.strictEqual(
        pc.signalingState,
        "stable",
        "ends negotiation in a stable state"
      );

      const remoteTrack = createFakeTrack("peer-2-track");
      const remoteStream = createFakeStream("peer-2-stream", remoteTrack);
      pc.ontrack({ streams: [remoteStream], track: remoteTrack });
      await wait(10);

      assert.true(
        this.subject
          .remoteStreamsFor(1)
          .some((stream) =>
            stream.getTracks().some((track) => track.id === "peer-2-track")
          ),
        "exposes the peer's audio after a slow-permission join"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("join with both a lower- and higher-id peer only offers to the higher-id one", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];

    // Local id sits between the two peers: it owns the offer to the
    // higher-id peer (99) and waits for the lower-id peer (2) to offer.
    this.currentUser.id = 10;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
      { id: 99, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(signalPayloadFrom(request));
      return response({});
    });

    try {
      await this.subject.join(this.room);
      await waitUntil(() => signalRequests.length === 1, 1000);

      assert.deepEqual(
        signalRequests,
        [{ recipientId: 99, type: "offer", sdp: "fake-offer" }],
        "offers immediately only to the higher-id peer, not the lower-id one"
      );

      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        data: { type: "offer", sdp: "peer-offer" },
      });
      await waitUntil(() => signalRequests.length === 2, 1000);

      assert.deepEqual(
        signalRequests[1],
        { recipientId: 2, type: "answer", sdp: "fake-answer" },
        "answers the lower-id peer when its offer arrives"
      );
      assert.false(
        signalRequests.some(
          (request) => request.recipientId === 2 && request.type === "offer"
        ),
        "never sends a competing offer to the lower-id peer"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("honors an early offer from a participant whose presence has not propagated yet", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    const signalRequests = [];
    const signalSessionIds = [];

    // The regression: two peers join near-simultaneously. The other peer
    // gathers and offers before our presence broadcast lists it, so
    // active_participants still only contains us when its offer arrives.
    // Gating on the local roster used to silently drop that offer and strand
    // the connection; the relay is server-attested (the server only relays
    // for senders holding a live participant session), so we must answer it.
    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", (request) => {
      signalRequests.push(signalPayloadFrom(request));
      signalSessionIds.push(
        new URLSearchParams(request.requestBody).get("participant_session_id")
      );
      return response({});
    });

    try {
      await this.subject.join(this.room);
      await wait(50);

      assert.strictEqual(
        signalRequests.length,
        0,
        "is alone in the room per presence, so sends nothing on its own"
      );

      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        sender: { id: 2, username: "early-bird" },
        data: { type: "offer", sdp: "early-offer" },
      });
      await waitUntil(() => signalRequests.length === 1, 1500);

      assert.deepEqual(
        signalRequests[0],
        { recipientId: 2, type: "answer", sdp: "fake-answer" },
        "answers the early offer despite the sender being absent from presence"
      );
      assert.strictEqual(
        signalSessionIds[0],
        "session-abc",
        "authenticates the answer with the join's participant session"
      );
      assert.true(
        (this.room.active_participants || []).some(
          (participant) => Number(participant.id) === 2
        ),
        "renders the server-serialized sender as a provisional participant"
      );

      const pc = FakeRTCPeerConnection.instances[0];
      assert.strictEqual(
        pc.remoteDescription.sdp,
        "early-offer",
        "applies the early offer as the remote description"
      );
      assert.strictEqual(
        pc.signalingState,
        "stable",
        "completes negotiation rather than dropping the offer"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("queues an early ICE candidate that arrives before its offer and applies it once engaged", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });

    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", () => response({}));

    const candidate = {
      candidate: "candidate:1 1 UDP 2122252543 127.0.0.1 3478 typ host",
      sdpMid: "0",
      sdpMLineIndex: 0,
    };

    try {
      await this.subject.join(this.room);
      await wait(50);

      // A candidate can land a beat ahead of its offer; with no peer yet it
      // must be stashed, not dropped.
      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        data: { type: "candidate", candidate },
      });
      await wait(20);

      assert.strictEqual(
        FakeRTCPeerConnection.created,
        0,
        "does not create a peer from a lone candidate"
      );

      // The offer then engages the peer, which flushes the queued candidate.
      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        data: { type: "offer", sdp: "early-offer" },
      });
      await waitUntil(() => FakeRTCPeerConnection.instances.length === 1, 1500);

      const pc = FakeRTCPeerConnection.instances[0];
      await waitUntil(() => pc.addedCandidates.length === 1, 1000);

      assert.strictEqual(
        pc.addedCandidates[0].candidate,
        candidate.candidate,
        "applies the candidate that arrived before the offer"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("keeps an early-offer peer alive through stale participant snapshots", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });

    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", () => response({}));

    const candidate = {
      candidate: "candidate:1 1 UDP 2122252543 127.0.0.1 3478 typ host",
      sdpMid: "0",
      sdpMLineIndex: 0,
    };

    try {
      await this.subject.join(this.room);
      await wait(50);

      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        data: { type: "offer", sdp: "early-offer" },
      });
      await waitUntil(() => FakeRTCPeerConnection.instances.length === 1);

      this.rooms.emit(1, {
        type: "participants",
        participants: [{ id: this.currentUser.id, role: "participant" }],
      });
      await wait(20);

      const pc = FakeRTCPeerConnection.instances[0];
      assert.strictEqual(
        FakeRTCPeerConnection.created,
        1,
        "keeps the peer created by the early targeted offer"
      );

      this.rooms.emit(1, {
        type: "signal",
        sender_id: 2,
        data: { type: "candidate", candidate },
      });
      await waitUntil(() => pc.addedCandidates.length === 1);

      assert.strictEqual(
        pc.addedCandidates[0].candidate,
        candidate.candidate,
        "applies candidates while waiting for presence to include the peer"
      );

      this.rooms.emit(1, {
        type: "participants",
        participants: [
          { id: this.currentUser.id, role: "participant" },
          { id: 2, role: "participant" },
        ],
      });
      await wait(20);

      assert.strictEqual(
        FakeRTCPeerConnection.created,
        1,
        "does not recreate the peer once presence catches up"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("recreates the peer when the remote restarts ICE after a rejoin", async function (assert) {
    assert.timeout(2000);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });

    // Local user is higher-id, so it answers the peer rather than offering.
    this.currentUser.id = 50;
    this.room.room_type = "open";
    this.room.membership.role_name = "participant";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/signal", () => response({}));

    const offer = (ufrag) => ({
      type: "offer",
      sdp: `v=0\r\na=ice-ufrag:${ufrag}\r\na=ice-pwd:secret\r\n`,
    });

    try {
      await this.subject.join(this.room);
      await wait(20);

      this.rooms.emit(1, { type: "signal", sender_id: 2, data: offer("AAAA") });
      await wait(20);
      assert.strictEqual(
        FakeRTCPeerConnection.created,
        1,
        "creates a single peer for the initial offer"
      );

      // A resent offer with the same ICE ufrag is not a restart; keep the peer.
      this.rooms.emit(1, { type: "signal", sender_id: 2, data: offer("AAAA") });
      await wait(20);
      assert.strictEqual(
        FakeRTCPeerConnection.created,
        1,
        "does not recreate the peer when the ICE ufrag is unchanged"
      );

      // A fresh offer with a NEW ufrag means the peer left and rejoined; the
      // stale transport can't recover, so the peer must be rebuilt.
      this.rooms.emit(1, { type: "signal", sender_id: 2, data: offer("BBBB") });
      await waitUntil(() => FakeRTCPeerConnection.created === 2, 1000);

      const freshPc = FakeRTCPeerConnection.instances.at(-1);
      assert.true(
        freshPc.remoteDescription.sdp.includes("ice-ufrag:BBBB"),
        "applies the restarted offer on the freshly created peer"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("inbound recovery signals cancel a pending peer restart", async function (assert) {
    assert.timeout(5000);

    // Short restart delay so a restart that survives the cancelation would
    // fire well inside the observation window below.
    setPeerTimingForTesting({
      ...SAFE_PEER_TIMING,
      restartDisconnectedDelayMs: 400,
    });

    let signalRequests = 0;

    pretender.post("/voice/rooms/1/signal", () => {
      signalRequests++;
      return response({});
    });

    await this.subject.join(this.room);
    await wait(50);

    const pc = FakeRTCPeerConnection.instances[0];
    pc.connectionState = "disconnected";
    pc.onconnectionstatechange();

    // The recovery offer is emitted immediately, so its handling (which
    // cancels the pending restart) only races the restart timer across a
    // microtask hop, not across fixed waits.
    this.rooms.emit(1, {
      type: "signal",
      sender_id: 2,
      data: { type: "offer", sdp: "recovery-offer" },
    });
    await waitUntil(() => signalRequests === 1, 1000);
    // Wait 3x past the restart delay to prove the canceled timer stays dead.
    await wait(1200);

    assert.strictEqual(
      signalRequests,
      1,
      "sends only the recovery answer and does not fire a stale restart offer"
    );
    assert.strictEqual(
      FakeRTCPeerConnection.created,
      1,
      "keeps the existing peer instead of recreating it after recovery signaling"
    );
  });

  test("enabling noise suppression preserves mute state across multiple peers", async function (assert) {
    const rawTrack = createFakeTrack("raw-track");
    const processedTrack = createFakeTrack("processed-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const processedStream = createFakeStream(
      "processed-stream",
      processedTrack
    );
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream,
    });

    this.room.membership.role_name = "speaker";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "speaker" },
      { id: 30, role: "speaker" },
    ];

    try {
      await this.subject.join(this.room);
      await wait(50);

      this.subject.toggleMute();

      await this.subject.setNoiseSuppressionMode("ai:dtln");

      assert.true(
        this.subject.noiseSuppressionEnabled,
        "marks noise suppression as enabled"
      );
      assert.strictEqual(
        this.subject.localStream,
        processedStream,
        "swaps to the processed stream"
      );

      FakeRTCPeerConnection.instances.forEach((pc, index) => {
        const sender = pc.getSenders()[0];

        assert.strictEqual(
          sender.track,
          processedTrack,
          `peer ${index + 1} switches to the processed track`
        );
        assert.false(
          sender.track.enabled,
          `peer ${index + 1} keeps the muted state after the stream swap`
        );
      });
    } finally {
      audioEnvironment.restore();
    }
  });

  test("disabling noise suppression preserves mute state across multiple peers", async function (assert) {
    const rawTrack = createFakeTrack("raw-track");
    const processedTrack = createFakeTrack("processed-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const processedStream = createFakeStream(
      "processed-stream",
      processedTrack
    );
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream,
    });

    this.room.membership.role_name = "speaker";
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "speaker" },
      { id: 30, role: "speaker" },
    ];

    localStorage.setItem("voice:noise-suppression-mode", "ai:dtln");

    try {
      await this.subject.join(this.room);
      await wait(50);

      this.subject.toggleMute();
      await this.subject.setNoiseSuppressionMode("standard");

      assert.false(
        this.subject.noiseSuppressionEnabled,
        "marks noise suppression as disabled"
      );
      assert.strictEqual(
        this.subject.localStream,
        rawStream,
        "restores the raw microphone stream"
      );
      assert.strictEqual(
        audioEnvironment.sourceStreams.filter((stream) => stream === rawStream)
          .length,
        2,
        "rebinds the local speaking monitor to the restored raw stream"
      );

      FakeRTCPeerConnection.instances.forEach((pc, index) => {
        const sender = pc.getSenders()[0];

        assert.strictEqual(
          sender.track,
          rawTrack,
          `peer ${index + 1} switches back to the raw track`
        );
        assert.false(
          sender.track.enabled,
          `peer ${index + 1} keeps the muted state after restoring the raw stream`
        );
      });
    } finally {
      localStorage.removeItem("voice:noise-suppression");
      localStorage.removeItem("voice:noise-suppression-mode");
      audioEnvironment.restore();
    }
  });

  test("changing the noise suppression mode without a microphone only stores the preference", async function (assert) {
    try {
      await this.subject.setNoiseSuppressionMode("ai:dtln");

      assert.strictEqual(
        this.subject.noiseSuppressionMode,
        "ai:dtln",
        "marks AI suppression as preferred for the next mic acquisition"
      );
      assert.strictEqual(
        localStorage.getItem("voice:noise-suppression-mode"),
        "ai:dtln",
        "persists the preference"
      );

      await this.subject.setNoiseSuppressionMode("standard");

      assert.strictEqual(
        this.subject.noiseSuppressionMode,
        "standard",
        "marks standard suppression as preferred"
      );
      assert.strictEqual(
        localStorage.getItem("voice:noise-suppression-mode"),
        "standard",
        "persists the new mode"
      );
    } finally {
      localStorage.removeItem("voice:noise-suppression-mode");
    }
  });

  test("leaving the room page stops an active camera publication", async function (assert) {
    this.room.video_allowed = true;
    this.room.screen_share_allowed = true;
    this.siteSettings.voice_video_max_publishers = 8;

    this.room.room_type = "open";
    this.room.video_enabled = true;
    this.room.membership = { role_name: "participant" };
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant", watching_video: true },
    ];

    const stateRequests = [];
    pretender.post("/voice/rooms/1/state", (request) => {
      stateRequests.push(
        Object.fromEntries(new URLSearchParams(request.requestBody))
      );
      return response({});
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });

    let cameraStopped = false;
    const cameraTrack = {
      id: "camera-track",
      kind: "video",
      enabled: true,
      contentHint: "",
      stop() {
        cameraStopped = true;
      },
      addEventListener() {},
    };
    const cameraStream = {
      id: "camera-stream",
      getTracks: () => [cameraTrack],
      getVideoTracks: () => [cameraTrack],
    };

    navigator.mediaDevices.getUserMedia = async (constraints) =>
      constraints?.video ? cameraStream : rawStream;

    try {
      await this.subject.join(this.room);
      await wait(50);

      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();

      assert.strictEqual(
        this.subject.localVideoKind,
        "camera",
        "camera publication starts from the room page"
      );

      const requestsBeforeLeave = stateRequests.length;
      this.subject.setWatching(1, false);
      await wait(10);

      assert.strictEqual(
        this.subject.localVideoKind,
        null,
        "publication stops when the user leaves the room page"
      );
      assert.true(
        cameraStopped,
        "the camera track is stopped so the device light turns off"
      );

      const leaveRequests = stateRequests.slice(requestsBeforeLeave);
      assert.deepEqual(
        leaveRequests,
        [
          {
            watching: "false",
            video: "false",
            screen: "false",
            participant_session_id: "session-abc",
          },
        ],
        "page leave sends one combined state request so concurrent " +
          "read-modify-write updates cannot resurrect stale publisher flags"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  function createFakeCameraTrack(id) {
    return {
      id,
      kind: "video",
      enabled: true,
      contentHint: "",
      stopped: false,
      stop() {
        this.stopped = true;
      },
      addEventListener() {},
    };
  }

  function createEndableCameraTrack(id) {
    const track = createFakeCameraTrack(id);
    let ended;
    track.addEventListener = (event, callback) => {
      if (event === "ended") {
        ended = callback;
      }
    };
    track.end = () => ended?.();
    return track;
  }

  function createFakeCameraStream(id, track) {
    return {
      id,
      getTracks: () => [track],
      getVideoTracks: () => [track],
    };
  }

  function setupCameraRoom(context) {
    context.room.video_allowed = true;
    context.room.screen_share_allowed = true;
    context.siteSettings.voice_video_max_publishers = 8;

    context.room.room_type = "open";
    context.room.video_enabled = true;
    context.room.membership = { role_name: "participant" };
    context.room.active_participants = [
      { id: context.currentUser.id, role: "participant" },
    ];

    pretender.post("/voice/rooms/1/state", () => response({}));
  }

  test("explicit camera toggles update the remembered preference", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    const cameraTrack = createFakeCameraTrack("camera-track");
    const cameraStream = createFakeCameraStream("camera-stream", cameraTrack);
    navigator.mediaDevices.getUserMedia = async (constraints) =>
      constraints?.video ? cameraStream : rawStream;

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);

      await this.subject.toggleCamera();

      assert.strictEqual(
        this.keyValueStore.get(this.cameraPreferenceKey),
        "true",
        "remembers a successfully started camera"
      );

      await this.subject.toggleCamera();

      assert.strictEqual(
        this.keyValueStore.get(this.cameraPreferenceKey),
        undefined,
        "clears the preference when the user turns the camera off"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("a remembered camera restarts after leaving and joining another watched room", async function (assert) {
    setupCameraRoom(this);

    const secondRoom = {
      ...this.room,
      id: 2,
      name: "Second room",
      active_participants: [{ id: this.currentUser.id, role: "participant" }],
    };
    this.rooms.seedRoom(secondRoom);
    pretender.post("/voice/rooms/2/join", () =>
      response({
        participant_session_id: "session-def",
        room: JSON.parse(JSON.stringify(secondRoom)),
      })
    );
    pretender.post("/voice/rooms/2/state", () => response({}));
    pretender.delete("/voice/rooms/2/leave", () => response({}));

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    const cameraTracks = [];
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }

      const track = createFakeCameraTrack(
        `camera-track-${cameraTracks.length}`
      );
      cameraTracks.push(track);
      return createFakeCameraStream(
        `camera-stream-${cameraTracks.length}`,
        track
      );
    };

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();

      this.subject.leave(this.room, { keepLocalStream: true });

      assert.true(
        cameraTracks[0].stopped,
        "releases the first room's camera track while preserving intent"
      );

      await this.subject.join(secondRoom);
      this.subject.setWatching(2, true);
      await waitUntil(() => this.subject.localVideoKind === "camera");

      assert.strictEqual(
        cameraTracks.length,
        2,
        "acquires a fresh camera stream without another camera-button click"
      );
      assert.strictEqual(
        this.keyValueStore.get(this.cameraPreferenceKey),
        "true",
        "keeps the remembered camera preference"
      );
    } finally {
      this.subject.leave(secondRoom, { keepLocalStream: true });
      audioEnvironment.restore();
    }
  });

  test("a remembered camera waits for a visible call surface", async function (assert) {
    setupCameraRoom(this);
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    let cameraCaptures = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }

      cameraCaptures++;
      const track = createFakeCameraTrack("camera-track");
      return createFakeCameraStream("camera-stream", track);
    };

    try {
      await this.subject.join(this.room);
      await wait(20);

      assert.strictEqual(
        cameraCaptures,
        0,
        "does not capture while the room has no visible controls"
      );

      this.subject.setWatching(1, true);
      await waitUntil(() => this.subject.localVideoKind === "camera");

      assert.strictEqual(
        cameraCaptures,
        1,
        "captures after the room page or call widget becomes visible"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("a pending camera restore is deduplicated and canceled when its controls disappear", async function (assert) {
    setupCameraRoom(this);
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    const cameraGranted = deferred();
    const cameraTrack = createFakeCameraTrack("camera-track");
    const cameraStream = createFakeCameraStream("camera-stream", cameraTrack);
    let cameraCaptures = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }

      cameraCaptures++;
      return cameraGranted.promise;
    };

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      this.subject.setWatching(1, true);
      await waitUntil(() => cameraCaptures === 1);

      this.subject.setWatching(1, false);
      cameraGranted.resolve(cameraStream);
      await waitUntil(() => cameraTrack.stopped);

      assert.strictEqual(
        cameraCaptures,
        1,
        "uses one capture request for repeated watching updates"
      );
      assert.strictEqual(
        this.subject.localVideoKind,
        null,
        "does not publish after the visible controls disappear"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("an in-flight camera restore does not replace an explicit screen share", async function (assert) {
    setupCameraRoom(this);
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    const cameraGranted = deferred();
    const cameraTrack = createFakeCameraTrack("camera-track");
    const cameraStream = createFakeCameraStream("camera-stream", cameraTrack);
    const screenTrack = createFakeCameraTrack("screen-track");
    const screenStream = {
      ...createFakeCameraStream("screen-stream", screenTrack),
      getAudioTracks: () => [],
    };
    const originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia;
    navigator.mediaDevices.getUserMedia = async (constraints) =>
      constraints?.video ? cameraGranted.promise : rawStream;
    navigator.mediaDevices.getDisplayMedia = async () => screenStream;

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await this.subject.toggleScreenShare();

      cameraGranted.resolve(cameraStream);
      await waitUntil(() => cameraTrack.stopped);

      assert.strictEqual(
        this.subject.localVideoKind,
        "screen",
        "keeps the explicitly selected screen share active"
      );
      assert.false(
        screenTrack.stopped,
        "does not stop the screen track when camera capture resolves"
      );
    } finally {
      if (originalGetDisplayMedia) {
        navigator.mediaDevices.getDisplayMedia = originalGetDisplayMedia;
      } else {
        delete navigator.mediaDevices.getDisplayMedia;
      }
      audioEnvironment.restore();
    }
  });

  test("stopping a screen share restores the previously enabled camera", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    const cameraTracks = [];
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }

      const track = createFakeCameraTrack(
        `camera-track-${cameraTracks.length}`
      );
      cameraTracks.push(track);
      return createFakeCameraStream(
        `camera-stream-${cameraTracks.length}`,
        track
      );
    };
    const screenTrack = createFakeCameraTrack("screen-track");
    const screenStream = {
      ...createFakeCameraStream("screen-stream", screenTrack),
      getAudioTracks: () => [],
    };
    const originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia;
    navigator.mediaDevices.getDisplayMedia = async () => screenStream;

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();
      await this.subject.toggleScreenShare();

      assert.strictEqual(
        this.subject.localVideoKind,
        "screen",
        "replaces the camera with the screen share"
      );

      await this.subject.toggleScreenShare();
      await waitUntil(() => this.subject.localVideoKind === "camera");

      assert.strictEqual(
        cameraTracks.length,
        2,
        "reacquires the camera after screen sharing stops"
      );
    } finally {
      if (originalGetDisplayMedia) {
        navigator.mediaDevices.getDisplayMedia = originalGetDisplayMedia;
      } else {
        delete navigator.mediaDevices.getDisplayMedia;
      }
      audioEnvironment.restore();
    }
  });

  test("stopping a screen share keeps a previously disabled camera off", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    let cameraCaptures = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (constraints?.video) {
        cameraCaptures++;
      }
      return rawStream;
    };
    const screenTrack = createFakeCameraTrack("screen-track");
    const screenStream = {
      ...createFakeCameraStream("screen-stream", screenTrack),
      getAudioTracks: () => [],
    };
    const originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia;
    navigator.mediaDevices.getDisplayMedia = async () => screenStream;

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await this.subject.toggleScreenShare();
      await this.subject.toggleScreenShare();
      await wait(20);

      assert.strictEqual(
        cameraCaptures,
        0,
        "does not acquire a camera without a remembered camera-on choice"
      );
      assert.strictEqual(this.subject.localVideoKind, null, "leaves video off");
    } finally {
      if (originalGetDisplayMedia) {
        navigator.mediaDevices.getDisplayMedia = originalGetDisplayMedia;
      } else {
        delete navigator.mediaDevices.getDisplayMedia;
      }
      audioEnvironment.restore();
    }
  });

  test("the browser's stop-sharing action restores the previously enabled camera", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    let cameraCaptures = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }

      cameraCaptures++;
      const track = createFakeCameraTrack(`camera-track-${cameraCaptures}`);
      return createFakeCameraStream(`camera-stream-${cameraCaptures}`, track);
    };
    const screenTrack = createEndableCameraTrack("screen-track");
    const screenStream = {
      ...createFakeCameraStream("screen-stream", screenTrack),
      getAudioTracks: () => [],
    };
    const originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia;
    navigator.mediaDevices.getDisplayMedia = async () => screenStream;

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();
      await this.subject.toggleScreenShare();

      screenTrack.end();
      await waitUntil(
        () => this.subject.localVideoKind === "camera" && cameraCaptures === 2
      );

      assert.strictEqual(
        this.subject.localVideoKind,
        "camera",
        "restores the camera after the browser ends screen capture"
      );
    } finally {
      if (originalGetDisplayMedia) {
        navigator.mediaDevices.getDisplayMedia = originalGetDisplayMedia;
      } else {
        delete navigator.mediaDevices.getDisplayMedia;
      }
      audioEnvironment.restore();
    }
  });

  test("a delayed ended event cannot stop a replacement screen share", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    const cameraTrack = createEndableCameraTrack("camera-track");
    const cameraStream = createFakeCameraStream("camera-stream", cameraTrack);
    navigator.mediaDevices.getUserMedia = async (constraints) =>
      constraints?.video ? cameraStream : rawStream;
    const screenTrack = createFakeCameraTrack("screen-track");
    const screenStream = {
      ...createFakeCameraStream("screen-stream", screenTrack),
      getAudioTracks: () => [],
    };
    const originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia;
    navigator.mediaDevices.getDisplayMedia = async () => screenStream;

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();
      await this.subject.toggleScreenShare();

      cameraTrack.end();
      await wait(20);

      assert.strictEqual(
        this.subject.localVideoKind,
        "screen",
        "ignores an ended event from the replaced camera pipeline"
      );
      assert.false(
        screenTrack.stopped,
        "keeps the replacement screen track active"
      );
    } finally {
      if (originalGetDisplayMedia) {
        navigator.mediaDevices.getDisplayMedia = originalGetDisplayMedia;
      } else {
        delete navigator.mediaDevices.getDisplayMedia;
      }
      audioEnvironment.restore();
    }
  });

  test("a failed explicit camera start does not create a preference", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (constraints?.video) {
        throw new DOMException("Permission denied", "NotAllowedError");
      }
      return rawStream;
    };

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();

      assert.strictEqual(
        this.keyValueStore.get(this.cameraPreferenceKey),
        undefined,
        "keeps future calls camera-off after capture is denied"
      );
      assert.strictEqual(
        this.subject.connectionStateFor(1),
        "connected",
        "keeps the audio call connected"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("a failed automatic camera restore stays silent", async function (assert) {
    setupCameraRoom(this);
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (constraints?.video) {
        throw new DOMException("Camera unavailable", "NotFoundError");
      }
      return rawStream;
    };

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await wait(20);

      const toasts = this.owner.lookup("service:toasts");
      assert.deepEqual(
        toasts.errors,
        [],
        "does not report a background capture failure as a user action"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("a watched room restores the camera when its join finishes", async function (assert) {
    setupCameraRoom(this);
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    let cameraCaptures = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }

      cameraCaptures++;
      const track = createFakeCameraTrack("camera-track");
      return createFakeCameraStream("camera-stream", track);
    };

    try {
      this.subject.setWatching(1, true);
      await this.subject.join(this.room);
      await waitUntil(() => this.subject.localVideoKind === "camera");

      assert.strictEqual(
        cameraCaptures,
        1,
        "restores after joining a room whose page was already visible"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("a camera click cancels an in-flight automatic restore", async function (assert) {
    setupCameraRoom(this);
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    const cameraGranted = deferred();
    const cameraTrack = createFakeCameraTrack("camera-track");
    const cameraStream = createFakeCameraStream("camera-stream", cameraTrack);
    let cameraCaptures = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }

      cameraCaptures++;
      return cameraGranted.promise;
    };

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await waitUntil(() => cameraCaptures === 1);

      const toggle = this.subject.toggleCamera();
      cameraGranted.resolve(cameraStream);
      await toggle;

      assert.strictEqual(
        this.subject.localVideoKind,
        null,
        "keeps the camera off after the explicit click"
      );
      assert.true(
        cameraTrack.stopped,
        "releases the capture granted after cancellation"
      );
      assert.strictEqual(
        this.keyValueStore.get(this.cameraPreferenceKey),
        undefined,
        "remembers the explicit camera-off choice"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("a remembered camera does not bypass room video permissions", async function (assert) {
    setupCameraRoom(this);
    this.room.video_enabled = false;
    this.keyValueStore.set({
      key: this.cameraPreferenceKey,
      value: "true",
    });

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });
    let cameraCaptures = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (constraints?.video) {
        cameraCaptures++;
      }
      return rawStream;
    };

    try {
      await this.subject.join(this.room);
      this.subject.setWatching(1, true);
      await wait(20);

      assert.strictEqual(
        cameraCaptures,
        0,
        "does not acquire video in a room where publishing is forbidden"
      );
      assert.strictEqual(
        this.keyValueStore.get(this.cameraPreferenceKey),
        "true",
        "preserves the preference for a later eligible room"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("setVideoInputDevice releases the live camera and retries when the hardware is busy", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });

    const frontTrack = createFakeCameraTrack("front-track");
    const frontStream = createFakeCameraStream("front-stream", frontTrack);
    const rearTrack = createFakeCameraTrack("rear-track");
    const rearStream = createFakeCameraStream("rear-stream", rearTrack);

    // Mimics a phone: the rear camera can't open until the front capture is
    // released.
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }
      if (constraints.video.deviceId?.exact === "rear") {
        if (!frontTrack.stopped) {
          throw new DOMException("busy", "NotReadableError");
        }
        return rearStream;
      }
      return frontStream;
    };

    try {
      await this.subject.join(this.room);
      await wait(50);
      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();

      assert.true(await this.subject.setVideoInputDevice("rear"));
      assert.strictEqual(
        this.subject.videoInputDeviceId,
        "rear",
        "the selection lands on the requested camera"
      );
      assert.true(
        frontTrack.stopped,
        "releases the current capture so the new camera can open"
      );
      assert.false(rearTrack.stopped, "keeps the new capture live");
      assert.strictEqual(
        this.subject.localVideoTrack?.id,
        "rear-track",
        "publishes the new camera's track"
      );
    } finally {
      audioEnvironment.restore();
      localStorage.removeItem("voice_video_input_device");
    }
  });

  test("setVideoInputDevice reacquires the previous camera when the retry also fails", async function (assert) {
    setupCameraRoom(this);

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });

    const frontTrack = createFakeCameraTrack("front-track");
    const frontStream = createFakeCameraStream("front-stream", frontTrack);
    const recoveredTrack = createFakeCameraTrack("recovered-track");
    const recoveredStream = createFakeCameraStream(
      "recovered-stream",
      recoveredTrack
    );

    let frontOpens = 0;
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      if (!constraints?.video) {
        return rawStream;
      }
      if (constraints.video.deviceId?.exact === "rear") {
        throw new DOMException("busy", "NotReadableError");
      }
      frontOpens += 1;
      return frontOpens === 1 ? frontStream : recoveredStream;
    };

    try {
      await this.subject.join(this.room);
      await wait(50);
      this.subject.setWatching(1, true);
      await this.subject.toggleCamera();

      assert.false(await this.subject.setVideoInputDevice("rear"));
      assert.strictEqual(
        this.subject.videoInputDeviceId,
        "system_default",
        "keeps the selection on the camera that is actually live"
      );
      assert.strictEqual(
        this.subject.localVideoKind,
        "camera",
        "the camera stays published"
      );
      assert.strictEqual(
        this.subject.localVideoTrack?.id,
        "recovered-track",
        "publishes a fresh capture of the previous camera, since the old one was released for the retry"
      );
    } finally {
      audioEnvironment.restore();
      localStorage.removeItem("voice_video_input_device");
    }
  });

  test("remote camera start exposes the negotiated video track without a refresh", async function (assert) {
    assert.timeout(2000);

    this.room.video_allowed = true;
    this.room.screen_share_allowed = true;
    this.siteSettings.voice_video_max_publishers = 8;

    this.room.room_type = "open";
    this.room.video_enabled = true;
    this.room.membership = { role_name: "participant" };
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      {
        id: 2,
        role: "participant",
        is_video_on: false,
        is_screen_sharing: false,
      },
    ];

    const rawTrack = createFakeTrack("raw-track");
    const rawStream = createFakeStream("raw-stream", rawTrack);
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: rawStream,
    });

    try {
      await this.subject.join(this.room);
      await wait(50);

      assert.strictEqual(
        this.subject.remoteStreamFor(1, 2),
        undefined,
        "starts without a stored remote media stream when no track event has fired"
      );

      this.rooms.emit(1, {
        type: "participants",
        participants: [
          { id: this.currentUser.id, role: "participant" },
          {
            id: 2,
            role: "participant",
            is_video_on: true,
            is_screen_sharing: false,
          },
        ],
      });

      await waitUntil(() => this.subject.remoteStreamFor(1, 2), 1000);

      assert.deepEqual(
        this.subject
          .remoteStreamFor(1, 2)
          .getVideoTracks()
          .map((track) => track.id),
        ["video-receiver-1"],
        "adds the already-negotiated remote video track when presence says the peer started publishing"
      );
    } finally {
      audioEnvironment.restore();
    }
  });

  test("videoAllowedIn denies a stage listener", function (assert) {
    this.room.video_allowed = true;
    this.room.screen_share_allowed = true;
    this.room.video_enabled = true;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "listener" },
      { id: 2, role: "speaker" },
    ];

    assert.false(
      this.subject.videoAllowedIn(this.room),
      "a stage listener cannot publish video"
    );
  });

  test("videoAllowedIn allows a stage speaker", function (assert) {
    this.room.video_allowed = true;
    this.room.screen_share_allowed = true;
    this.room.video_enabled = true;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "listener" },
    ];

    assert.true(
      this.subject.videoAllowedIn(this.room),
      "a stage speaker can publish video"
    );
  });

  test("videoAllowedIn allows a stage moderator", function (assert) {
    this.room.video_allowed = true;
    this.room.screen_share_allowed = true;
    this.room.video_enabled = true;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "moderator" },
      { id: 2, role: "listener" },
    ];

    assert.true(
      this.subject.videoAllowedIn(this.room),
      "a stage moderator can publish video"
    );
  });

  test("videoAllowedIn still requires the room's video flag for a stage speaker", function (assert) {
    this.room.video_allowed = true;
    this.room.video_enabled = false;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "speaker" },
      { id: 2, role: "listener" },
    ];

    assert.false(
      this.subject.videoAllowedIn(this.room),
      "the speaker role does not override a video-disabled room"
    );
  });

  test("videoAllowedIn does not role-gate open rooms", function (assert) {
    this.room.video_allowed = true;
    this.room.screen_share_allowed = true;
    this.room.room_type = "open";
    this.room.video_enabled = true;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
      { id: 2, role: "participant" },
    ];

    assert.true(
      this.subject.videoAllowedIn(this.room),
      "open-room participants can publish video regardless of role"
    );
  });

  test("camera and screen sharing are allowed independently", function (assert) {
    this.room.room_type = "open";
    this.room.video_enabled = true;
    this.room.video_allowed = true;
    this.room.screen_share_allowed = false;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
    ];

    assert.true(
      this.subject.videoAllowedIn(this.room),
      "the camera follows its own server-granted right"
    );
    assert.false(
      this.subject.screenShareAllowedIn(this.room),
      "screen sharing follows its own server-granted right"
    );

    this.room.video_allowed = false;
    this.room.screen_share_allowed = true;

    assert.false(this.subject.videoAllowedIn(this.room), "camera revoked");
    assert.true(
      this.subject.screenShareAllowedIn(this.room),
      "screen sharing granted"
    );
  });

  test("a room with media disabled overrides both granted rights", function (assert) {
    this.room.room_type = "open";
    this.room.video_enabled = false;
    this.room.video_allowed = true;
    this.room.screen_share_allowed = true;
    this.room.active_participants = [
      { id: this.currentUser.id, role: "participant" },
    ];

    assert.false(this.subject.videoAllowedIn(this.room));
    assert.false(this.subject.screenShareAllowedIn(this.room));
  });

  function createDeviceTrack(id, deviceId) {
    return {
      id,
      kind: "audio",
      enabled: true,
      stopped: false,
      stop() {
        this.stopped = true;
      },
      getSettings() {
        return { deviceId };
      },
    };
  }

  async function joinWithMic(context, rawStream) {
    const audioEnvironment = installFakeAudioEnvironment({
      rawStream,
      processedStream: createFakeStream(
        "processed-stream",
        createFakeTrack("processed-track")
      ),
    });
    context.room.room_type = "open";
    context.room.membership.role_name = "participant";
    context.room.active_participants = [
      { id: context.currentUser.id, role: "participant" },
    ];
    await context.subject.join(context.room);
    return audioEnvironment;
  }

  test("setInputDevice opens the picked device with an exact constraint and swaps streams", async function (assert) {
    const oldTrack = createDeviceTrack("track-a", "mic-a");
    const audioEnvironment = await joinWithMic(
      this,
      createFakeStream("stream-a", oldTrack)
    );

    const newTrack = createDeviceTrack("track-b", "mic-b");
    const requests = [];
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      requests.push(constraints);
      return createFakeStream("stream-b", newTrack);
    };

    try {
      assert.true(await this.subject.setInputDevice("mic-b"));
      assert.deepEqual(
        requests[0].audio.deviceId,
        { exact: "mic-b" },
        "requires the picked device instead of treating it as a preference"
      );
      assert.true(oldTrack.stopped, "stops the replaced capture");
      assert.false(newTrack.stopped, "keeps the new capture live");
    } finally {
      audioEnvironment.restore();
      localStorage.removeItem("voice_audio_input_device");
    }
  });

  test("setInputDevice reverts and keeps the current capture when the device can't be opened", async function (assert) {
    const oldTrack = createDeviceTrack("track-a", "mic-a");
    const audioEnvironment = await joinWithMic(
      this,
      createFakeStream("stream-a", oldTrack)
    );

    navigator.mediaDevices.getUserMedia = async () => {
      throw new DOMException("busy", "NotReadableError");
    };

    try {
      assert.false(await this.subject.setInputDevice("mic-b"));
      assert.strictEqual(
        this.subject.inputDeviceId,
        "system_default",
        "keeps the selection on the device that is actually live"
      );
      assert.false(oldTrack.stopped, "the live capture is left untouched");
    } finally {
      audioEnvironment.restore();
      localStorage.removeItem("voice_audio_input_device");
    }
  });
});
