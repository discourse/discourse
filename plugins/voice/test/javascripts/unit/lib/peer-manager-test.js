import { module, test } from "qunit";
import PeerManager from "discourse/plugins/voice/discourse/lib/voice/peer-manager";

class FakeRTCPeerConnection {
  signalingState = "stable";
  connectionState = "new";
  iceConnectionState = "new";
  iceGatheringState = "new";
  localDescription = null;
  #senders = [];
  #transceivers = [];

  constructor() {}

  addTrack(track) {
    const sender = { track };
    this.#senders.push(sender);
    return sender;
  }

  addTransceiver(kind) {
    const sender = {
      track: null,
      async replaceTrack(newTrack) {
        this.track = newTrack;
      },
    };
    const transceiver = {
      mid: null,
      direction: "sendrecv",
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

module("Voice | Unit | Lib | peer-manager", function (hooks) {
  hooks.beforeEach(function () {
    this.originalRTCPeerConnection = globalThis.RTCPeerConnection;
    globalThis.RTCPeerConnection = FakeRTCPeerConnection;
  });

  hooks.afterEach(function () {
    globalThis.RTCPeerConnection = this.originalRTCPeerConnection;
  });

  test("does not keep a restarted peer when the room becomes ineligible mid-restart", async function (assert) {
    let shouldRestart = true;
    let sentSignals = 0;

    const manager = new PeerManager({
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
    });

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

    const manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      getLocalScreenAudioTrack: () => screenAudioTrack,
      sendSignal: () => Promise.resolve(),
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
    });

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
    const manager = new PeerManager({
      getIceServers: () => [],
      getLocalStream: () => null,
      sendSignal: () => Promise.resolve(),
      flushQueuedSignals: () => Promise.resolve(),
      onTrack: () => {},
      clearSignalQueue: () => {},
      onPeerDestroyed: () => {},
    });

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
});
