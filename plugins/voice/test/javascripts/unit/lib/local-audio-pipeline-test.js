import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Site from "discourse/models/site";
import LocalAudioPipeline from "discourse/plugins/voice/discourse/lib/voice/local-audio-pipeline";

const STORAGE_KEYS = [
  "voice:noise-suppression",
  "voice:noise-suppression-mode",
  "voice:echo-cancellation",
  "voice:auto-gain-control",
];

function clearStoredPreferences() {
  STORAGE_KEYS.forEach((key) => localStorage.removeItem(key));
}

function createFakeTrack(id) {
  return { id, kind: "audio", enabled: true, stop() {} };
}

function createFakeStream(id, track) {
  return {
    id,
    getTracks: () => [track],
    getAudioTracks: () => [track],
  };
}

// A controllable stand-in for the DTLN worklet environment: tests decide
// when (and how) each AudioWorkletNode answers the ready handshake, and the
// getUserMedia constraints of every capture are recorded.
function installFakeEnvironment(context, { rawStream, processedStream }) {
  const workletNodes = [];
  const captureConstraints = [];

  class FakeAudioContext {
    state = "running";
    audioWorklet = {
      addModule: async () => {},
    };

    resume() {
      this.state = "running";
      return Promise.resolve();
    }

    createMediaStreamSource() {
      return {
        connect: (target) => target,
        disconnect() {},
      };
    }

    createMediaStreamDestination() {
      return { stream: processedStream };
    }

    close() {
      return Promise.resolve();
    }
  }

  class FakeAudioWorkletNode {
    port = {
      onmessage: null,
      postMessage: (data) => {
        if (data?.type === "init") {
          this.wasmReceived = true;
        }
      },
    };

    constructor() {
      workletNodes.push(this);
    }

    emit(message) {
      this.port.onmessage?.({ data: message });
    }

    connect(target) {
      return target;
    }

    disconnect() {}
  }

  context.originals = {
    audioContext: globalThis.AudioContext,
    workletNode: globalThis.AudioWorkletNode,
    windowAudioContext: window.AudioContext,
    fetch: globalThis.fetch,
    getUserMedia: navigator.mediaDevices?.getUserMedia,
  };

  // The gem-vendored asset base the loaders read at runtime.
  Site.current().set("voice_assets_path", "/plugins/voice/javascripts/0.0.0");
  const originalFetch = globalThis.fetch;
  globalThis.AudioContext = FakeAudioContext;
  window.AudioContext = FakeAudioContext;
  globalThis.AudioWorkletNode = FakeAudioWorkletNode;
  globalThis.fetch = (url, options) => {
    if (String(url).includes("/plugins/voice/javascripts/")) {
      return Promise.resolve({
        ok: true,
        arrayBuffer: async () => new ArrayBuffer(8),
      });
    }
    return originalFetch(url, options);
  };
  navigator.mediaDevices ||= {};
  navigator.mediaDevices.getUserMedia = async (constraints) => {
    captureConstraints.push(constraints.audio);
    return rawStream;
  };

  return { workletNodes, captureConstraints };
}

function restoreEnvironment(context) {
  globalThis.AudioContext = context.originals.audioContext;
  window.AudioContext = context.originals.windowAudioContext;
  globalThis.AudioWorkletNode = context.originals.workletNode;
  globalThis.fetch = context.originals.fetch;
  if (context.originals.getUserMedia) {
    navigator.mediaDevices.getUserMedia = context.originals.getUserMedia;
  } else {
    delete navigator.mediaDevices.getUserMedia;
  }
}

// Yields until the pipeline has posted the wasm to a worklet node, i.e. a
// setup() is parked on the ready handshake.
async function waitForWorkletNode(workletNodes, index = 0) {
  for (let i = 0; i < 50; i++) {
    if (workletNodes[index]?.wasmReceived) {
      return workletNodes[index];
    }
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  throw new Error("worklet node never received wasm bytes");
}

module("Voice | Unit | Lib | local-audio-pipeline", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    clearStoredPreferences();

    this.rawTrack = createFakeTrack("raw-track");
    this.rawStream = createFakeStream("raw-stream", this.rawTrack);
    this.processedTrack = createFakeTrack("processed-track");
    this.processedStream = createFakeStream(
      "processed-stream",
      this.processedTrack
    );

    this.env = installFakeEnvironment(this, {
      rawStream: this.rawStream,
      processedStream: this.processedStream,
    });

    this.suppressionFailures = 0;
    this.trackReplacements = 0;
    this.buildPipeline = () =>
      new LocalAudioPipeline({
        onStreamChanged: () => {},
        onSuppressionFailed: () => this.suppressionFailures++,
        replaceTrackOnPeers: async () => this.trackReplacements++,
      });
    this.pipeline = this.buildPipeline();
  });

  hooks.afterEach(function () {
    this.pipeline.stop();
    restoreEnvironment(this);
    clearStoredPreferences();
  });

  test("captures with the browser processing defaults", async function (assert) {
    await this.pipeline.acquireMicrophone();

    assert.deepEqual(this.env.captureConstraints[0], {
      echoCancellation: true,
      autoGainControl: true,
      noiseSuppression: true,
    });
    assert.strictEqual(this.pipeline.noiseSuppressionMode, "standard");
    assert.strictEqual(
      this.env.workletNodes.length,
      0,
      "standard mode never touches the worklet"
    );
  });

  test("AI mode resolves only after the worklet ready handshake and disables native suppression", async function (assert) {
    await this.pipeline.acquireMicrophone();

    const change = this.pipeline.setNoiseSuppressionMode("ai:dtln");
    const node = await waitForWorkletNode(this.env.workletNodes);

    assert.strictEqual(
      this.pipeline.noiseSuppressionState,
      "starting",
      "stays in starting until the worklet confirms"
    );
    assert.strictEqual(
      this.pipeline.stream,
      this.rawStream,
      "keeps publishing the previous stream while starting"
    );

    node.emit({ type: "ready" });
    await change;

    assert.strictEqual(this.pipeline.noiseSuppressionState, "on");
    assert.strictEqual(
      this.pipeline.stream,
      this.processedStream,
      "publishes the suppressed stream after ready"
    );
    assert.false(
      this.env.captureConstraints.at(-1).noiseSuppression,
      "native suppression is off underneath the AI filter"
    );
    assert.strictEqual(
      localStorage.getItem("voice:noise-suppression-mode"),
      "ai:dtln",
      "persists the mode only on success"
    );
    assert.strictEqual(this.trackReplacements, 1);
  });

  test("worklet init error reverts to the previous mode and notifies", async function (assert) {
    await this.pipeline.acquireMicrophone();

    const change = this.pipeline.setNoiseSuppressionMode("ai:dtln");
    const node = await waitForWorkletNode(this.env.workletNodes);
    node.emit({ type: "error", message: "boom" });
    await change;

    assert.strictEqual(this.pipeline.noiseSuppressionMode, "standard");
    assert.strictEqual(this.pipeline.noiseSuppressionState, "off");
    assert.strictEqual(
      this.pipeline.stream,
      this.rawStream,
      "keeps the raw stream"
    );
    assert.strictEqual(this.suppressionFailures, 1, "notifies the failure");
    assert.strictEqual(
      localStorage.getItem("voice:noise-suppression-mode"),
      "standard",
      "does not persist the failed mode"
    );
    assert.true(
      this.env.captureConstraints.at(-1).noiseSuppression,
      "recaptures with native suppression restored"
    );
  });

  test("rapid mode changes are serialized", async function (assert) {
    await this.pipeline.acquireMicrophone();

    const first = this.pipeline.setNoiseSuppressionMode("ai:dtln");
    const second = this.pipeline.setNoiseSuppressionMode("standard");

    const node = await waitForWorkletNode(this.env.workletNodes);
    node.emit({ type: "ready" });
    await first;
    await second;

    assert.strictEqual(
      this.pipeline.noiseSuppressionMode,
      "standard",
      "the second change runs after the first completes"
    );
    assert.strictEqual(this.pipeline.noiseSuppressionState, "off");
    assert.strictEqual(
      this.pipeline.stream,
      this.rawStream,
      "ends on the raw stream"
    );
    assert.strictEqual(
      this.env.workletNodes.length,
      1,
      "only one worklet setup ran"
    );
  });

  test("stop() during setup supersedes it without failure side effects", async function (assert) {
    await this.pipeline.acquireMicrophone();

    const change = this.pipeline.setNoiseSuppressionMode("ai:dtln");
    await waitForWorkletNode(this.env.workletNodes);

    this.pipeline.stop();
    await change;

    assert.strictEqual(
      this.suppressionFailures,
      0,
      "a superseded setup is not reported as a failure"
    );
    assert.strictEqual(this.pipeline.stream, null, "pipeline is stopped");
  });

  test("mid-call bypass falls back to standard suppression", async function (assert) {
    localStorage.setItem("voice:noise-suppression-mode", "ai:dtln");
    this.pipeline = this.buildPipeline();

    const acquired = this.pipeline.acquireMicrophone();
    const node = await waitForWorkletNode(this.env.workletNodes);
    node.emit({ type: "ready" });
    await acquired;

    assert.strictEqual(this.pipeline.noiseSuppressionState, "on");

    node.emit({ type: "bypass" });
    await new Promise((resolve) => setTimeout(resolve, 20));

    assert.strictEqual(this.pipeline.noiseSuppressionMode, "standard");
    assert.strictEqual(this.pipeline.noiseSuppressionState, "off");
    assert.strictEqual(
      this.pipeline.stream,
      this.rawStream,
      "peers fall back to the native-suppressed stream"
    );
    assert.strictEqual(this.suppressionFailures, 1);
    assert.strictEqual(
      localStorage.getItem("voice:noise-suppression-mode"),
      "standard",
      "persists the fallback so it doesn't loop"
    );
  });

  test("changing the mode without a microphone only stores the preference", async function (assert) {
    await this.pipeline.setNoiseSuppressionMode("ai:dtln");

    assert.strictEqual(this.pipeline.noiseSuppressionMode, "ai:dtln");
    assert.strictEqual(
      localStorage.getItem("voice:noise-suppression-mode"),
      "ai:dtln"
    );
    assert.strictEqual(
      this.env.workletNodes.length,
      0,
      "no worklet setup runs"
    );

    await this.pipeline.setNoiseSuppressionMode("none");
    assert.strictEqual(
      localStorage.getItem("voice:noise-suppression-mode"),
      "none"
    );
  });

  test("migrates the legacy boolean preference to AI mode", function (assert) {
    localStorage.setItem("voice:noise-suppression", "1");

    const pipeline = this.buildPipeline();

    assert.strictEqual(pipeline.noiseSuppressionMode, "ai:dtln");
  });

  test('migrates the legacy plain "ai" mode to the DTLN engine', function (assert) {
    localStorage.setItem("voice:noise-suppression-mode", "ai");

    const pipeline = this.buildPipeline();

    assert.strictEqual(pipeline.noiseSuppressionMode, "ai:dtln");
  });

  test("switching between AI engines rebuilds the worklet pipeline", async function (assert) {
    await this.pipeline.acquireMicrophone();

    const first = this.pipeline.setNoiseSuppressionMode("ai:dtln");
    (await waitForWorkletNode(this.env.workletNodes, 0)).emit({
      type: "ready",
    });
    await first;

    const second = this.pipeline.setNoiseSuppressionMode("ai:rnnoise");
    (await waitForWorkletNode(this.env.workletNodes, 1)).emit({
      type: "ready",
    });
    await second;

    assert.strictEqual(this.pipeline.noiseSuppressionMode, "ai:rnnoise");
    assert.strictEqual(this.pipeline.noiseSuppressionState, "on");
    assert.strictEqual(
      this.pipeline.stream,
      this.processedStream,
      "publishes the new engine's stream"
    );
    assert.strictEqual(
      this.env.workletNodes.length,
      2,
      "each engine got its own worklet"
    );
    assert.false(
      this.env.captureConstraints.at(-1).noiseSuppression,
      "native suppression stays off across AI engines"
    );
  });

  test("echo cancellation and auto gain changes recapture with new constraints", async function (assert) {
    await this.pipeline.acquireMicrophone();

    await this.pipeline.setEchoCancellation(false);
    assert.deepEqual(this.env.captureConstraints.at(-1), {
      echoCancellation: false,
      autoGainControl: true,
      noiseSuppression: true,
    });
    assert.strictEqual(localStorage.getItem("voice:echo-cancellation"), "0");

    await this.pipeline.setAutoGainControl(false);
    assert.deepEqual(this.env.captureConstraints.at(-1), {
      echoCancellation: false,
      autoGainControl: false,
      noiseSuppression: true,
    });
    assert.strictEqual(this.trackReplacements, 2);
  });
});
