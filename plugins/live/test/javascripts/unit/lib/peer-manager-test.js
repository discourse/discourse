import { module, test } from "qunit";
import PeerManager from "discourse/plugins/live/discourse/lib/live/peer-manager";

class FakeRTCPeerConnection {
  signalingState = "stable";
  connectionState = "new";
  iceConnectionState = "new";
  iceGatheringState = "new";
  localDescription = null;
  #senders = [];
  #transceivers = [];

  constructor() {}

  createDataChannel(label, options) {
    return { label, ...options };
  }

  addTrack(track) {
    const sender = { track };
    this.#senders.push(sender);
    return sender;
  }

  addTransceiver(kind, options = {}) {
    const sender = {
      track: null,
      async replaceTrack(newTrack) {
        this.track = newTrack;
      },
    };
    const transceiver = {
      mid: null,
      direction: options.direction ?? "sendrecv",
      sender,
      receiver: { track: { kind } },
    };
    this.#transceivers.push(transceiver);
    this.#senders.push(sender);
    return transceiver;
  }

  getTransceivers() {
    return this.#transceivers;
  }

  getSenders() {
    return this.#senders;
  }

  async createOffer() {
    return { type: "offer", sdp: "fake-offer" };
  }

  async setLocalDescription(description) {
    this.localDescription = description;
  }

  close() {
    this.connectionState = "closed";
  }
}

module("Live | Unit | Lib | peer-manager", function (hooks) {
  hooks.beforeEach(function () {
    this.originalRTCPeerConnection = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = FakeRTCPeerConnection;
  });

  hooks.afterEach(function () {
    this.manager?.destroyAll();
    globalThis.RTCPeerConnection = this.originalRTCPeerConnection;
  });

  test("pre-negotiates a reliable ordered file channel during initial setup", async function (assert) {
    let channel;
    this.manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      sendSignal: async () => {},
      flushQueuedSignals: async () => {},
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
      onFileChannel: (roomId, userId, value) => {
        assert.strictEqual(roomId, 1);
        assert.strictEqual(userId, 2);
        channel = value;
      },
    });
    await this.manager.create(1, 2);
    assert.deepEqual(
      channel,
      {
        label: "live-file-transfer",
        negotiated: true,
        id: 0,
        ordered: true,
      },
      "no maxRetransmits or maxPacketLifeTime: reliable delivery"
    );
  });

  test("does not keep a restarted peer when the room becomes ineligible mid-restart", async function (assert) {
    let shouldRestart = true;
    let sentSignals = 0;

    const manager = (this.manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      sendSignal: () => {
        sentSignals++;
        return Promise.resolve();
      },
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
      shouldRestartPeer: () => shouldRestart,
    }));

    await manager.create(1, 2);
    assert.true(manager.has(1, 2), "creates the initial peer");

    const restart = manager.restart(1, 2);
    shouldRestart = false;
    await restart;

    assert.false(
      manager.has(1, 2),
      "does not keep a recreated peer when restart is no longer allowed"
    );
    assert.strictEqual(sentSignals, 0, "does not emit a new offer");
  });

  test("alignVideoTransceiverForAnswer makes the negotiated transceiver sendable and migrates the orphaned track", async function (assert) {
    const makeSender = (track = null) => ({
      track,
      async replaceTrack(newTrack) {
        this.track = newTrack;
      },
    });

    const cameraTrack = { id: "camera", kind: "video" };
    const orphan = {
      mid: null,
      direction: "sendrecv",
      sender: makeSender(cameraTrack),
      receiver: { track: { kind: "video" } },
    };
    const associated = {
      mid: "1",
      direction: "recvonly",
      sender: makeSender(),
      receiver: { track: { kind: "video" } },
    };
    const pc = {
      getTransceivers() {
        return [orphan, associated];
      },
    };

    PeerManager.alignVideoTransceiverForAnswer(pc);
    await Promise.resolve();

    assert.strictEqual(
      associated.direction,
      "sendrecv",
      "flips the negotiated transceiver to sendrecv before the answer"
    );
    assert.strictEqual(
      associated.sender.track,
      cameraTrack,
      "moves the camera track onto the negotiated transceiver"
    );
    assert.strictEqual(
      orphan.sender.track,
      null,
      "detaches the camera track from the orphaned transceiver"
    );
    assert.strictEqual(
      PeerManager.videoTransceiverFor(pc),
      associated,
      "videoTransceiverFor prefers the negotiated transceiver"
    );
  });

  test("alignScreenAudioTransceiverForAnswer adopts the negotiated m-line and migrates the orphaned track", async function (assert) {
    const screenAudioTrack = { id: "screen-audio", kind: "audio" };

    const manager = (this.manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      getLocalScreenAudioTrack: () => screenAudioTrack,
      sendSignal: () => Promise.resolve(),
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
    }));

    const pc = await manager.create(1, 2);
    await Promise.resolve();

    const preAllocated = PeerManager.screenAudioTransceiverFor(pc);
    assert.strictEqual(
      preAllocated.sender.track,
      screenAudioTrack,
      "attaches the local screen audio track at peer setup"
    );

    // Simulate applying a remote offer: fresh recvonly transceivers appear
    // for each m-line the pre-allocated ones couldn't be reused for.
    const makeSender = (track = null) => ({
      track,
      async replaceTrack(newTrack) {
        this.track = newTrack;
      },
    });
    const micTransceiver = {
      mid: "0",
      direction: "recvonly",
      sender: makeSender(),
      receiver: { track: { kind: "audio" } },
    };
    const negotiated = {
      mid: "2",
      direction: "recvonly",
      sender: makeSender(),
      receiver: { track: { kind: "audio" } },
    };
    pc.getTransceivers().push(micTransceiver, negotiated);

    PeerManager.alignScreenAudioTransceiverForAnswer(pc);
    await Promise.resolve();

    assert.strictEqual(
      negotiated.direction,
      "sendrecv",
      "flips the negotiated transceiver to sendrecv before the answer"
    );
    assert.strictEqual(
      negotiated.sender.track,
      screenAudioTrack,
      "moves the screen audio track onto the negotiated transceiver"
    );
    assert.strictEqual(
      preAllocated.sender.track,
      null,
      "detaches the track from the orphaned transceiver"
    );
    assert.strictEqual(
      micTransceiver.direction,
      "recvonly",
      "leaves the mic m-line alone"
    );
    assert.strictEqual(
      PeerManager.screenAudioTransceiverFor(pc),
      negotiated,
      "screenAudioTransceiverFor returns the negotiated transceiver"
    );
  });

  test("alignScreenAudioTransceiverForAnswer leaves single-audio offers from older clients alone", async function (assert) {
    const manager = (this.manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      sendSignal: () => Promise.resolve(),
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
    }));

    const pc = await manager.create(1, 2);
    const preAllocated = PeerManager.screenAudioTransceiverFor(pc);

    const micTransceiver = {
      mid: "0",
      direction: "recvonly",
      sender: { track: null },
      receiver: { track: { kind: "audio" } },
    };
    pc.getTransceivers().push(micTransceiver);

    PeerManager.alignScreenAudioTransceiverForAnswer(pc);

    assert.strictEqual(
      micTransceiver.direction,
      "recvonly",
      "does not adopt the mic m-line as the screen audio slot"
    );
    assert.strictEqual(
      PeerManager.screenAudioTransceiverFor(pc),
      preAllocated,
      "keeps the pre-allocated transceiver as the screen audio slot"
    );
  });

  test("diagnosticsFor reports ICE candidate errors for the current connection", async function (assert) {
    const manager = (this.manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      sendSignal: () => Promise.resolve(),
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
    }));

    const pc = await manager.create(1, 2);
    pc.onicecandidateerror({
      url: "turn:turn.example.com:3478",
      errorCode: 401,
      errorText: "Unauthorized",
    });
    manager.queuePendingCandidate(1, 2, { candidate: "x" });

    const diagnostics = manager.diagnosticsFor(1, 2);

    assert.strictEqual(diagnostics.restartAttempts, 0);
    assert.strictEqual(diagnostics.pendingCandidates, 1);
    assert.strictEqual(diagnostics.iceCandidateErrors.length, 1);
    assert.strictEqual(diagnostics.iceCandidateErrors[0].errorCode, 401);
    assert.deepEqual(
      manager.diagnosticsFor(1, 3).iceCandidateErrors,
      [],
      "a peer without a connection has no errors"
    );
  });

  test("reserves an idle mic slot before video and screen audio when no local stream exists", async function (assert) {
    const manager = (this.manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      canPublishMedia: () => true,
      sendSignal: () => Promise.resolve(),
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
    }));

    const pc = await manager.create(1, 2);
    const transceivers = pc.getTransceivers();

    assert.deepEqual(
      transceivers.map((t) => ({
        kind: t.receiver.track.kind,
        direction: t.direction,
      })),
      [
        { kind: "audio", direction: "sendrecv" },
        { kind: "video", direction: "sendrecv" },
        { kind: "audio", direction: "sendrecv" },
      ],
      "reserves mic audio first, followed by video and screen audio"
    );
    assert.strictEqual(
      PeerManager.screenAudioTransceiverFor(pc),
      transceivers[2],
      "keeps screen audio on the second audio transceiver, not the mic slot"
    );
    assert.strictEqual(
      PeerManager.micSenderFor(pc),
      null,
      "reports no active mic sender when no local track is attached"
    );

    const track = { kind: "audio" };
    assert.true(
      await manager.attachMicTrack(1, track),
      "attaches a microphone captured later"
    );
    assert.strictEqual(
      transceivers[0].sender.track,
      track,
      "sends it on the reserved mic slot"
    );
    assert.strictEqual(
      PeerManager.micSenderFor(pc),
      transceivers[0].sender,
      "reports the mic sender once the track is attached"
    );
  });

  test("does not attach a late microphone to a receive-only mic slot", async function (assert) {
    const manager = (this.manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      canPublishMedia: () => false,
      sendSignal: () => Promise.resolve(),
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
    }));

    const pc = await manager.create(1, 2);

    assert.strictEqual(pc.getTransceivers()[0].direction, "recvonly");
    assert.false(
      await manager.attachMicTrack(1, { kind: "audio" }),
      "reports that the connection must be rebuilt"
    );
    assert.strictEqual(
      pc.getTransceivers()[0].sender.track,
      null,
      "leaves the sender untouched"
    );
  });

  test("an answerer without a microphone turns the offered mic m-line into an idle sender", function (assert) {
    const streams = [];
    const transceiver = (kind, mid, sender = {}) => ({
      mid,
      direction: "recvonly",
      sender: { track: null, setStreams: (s) => streams.push(s), ...sender },
      receiver: { track: { kind } },
    });
    const mic = transceiver("audio", "0");
    const pc = {
      getTransceivers: () => [
        transceiver("audio", null),
        mic,
        transceiver("video", "1"),
        transceiver("audio", "2"),
      ],
    };

    PeerManager.alignMicTransceiverForAnswer(pc);

    assert.strictEqual(mic.direction, "sendrecv", "can send a late mic");
    assert.strictEqual(
      streams.length,
      1,
      "gives the sender a stream so receivers treat it as a microphone"
    );
  });
});
