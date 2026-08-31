import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SubtitlesManager from "discourse/plugins/voice/discourse/lib/voice/subtitles";

function createFakeStream(id, trackId = `${id}-track`) {
  return {
    id,
    getAudioTracks: () => [{ id: trackId, kind: "audio" }],
    getTracks: () => [{ id: trackId, kind: "audio" }],
  };
}

// Speaks the worker protocol: init → ready (immediately), transcribe →
// caption echoing a canned text.
class FakeWorker {
  static instances = [];

  onmessage = null;
  onerror = null;
  terminated = false;
  jobs = [];
  messages = [];

  constructor() {
    FakeWorker.instances.push(this);
  }

  postMessage(message) {
    this.messages.push(message);
    if (message.type === "init") {
      Promise.resolve().then(() =>
        this.onmessage?.({ data: { type: "ready" } })
      );
    } else if (message.type === "transcribe") {
      this.jobs.push(message);
      Promise.resolve().then(() =>
        this.onmessage?.({
          data: {
            type: "caption",
            roomId: message.roomId,
            userId: message.userId,
            utteranceId: message.utteranceId,
            interim: message.interim,
            text: message.interim ? "hello" : "hello world",
          },
        })
      );
    }
  }

  emit(data) {
    this.onmessage?.({ data });
  }

  terminate() {
    this.terminated = true;
  }
}

class FakeVad {
  static instances = [];

  destroyed = false;

  constructor(options) {
    this.options = options;
    FakeVad.instances.push(this);
  }

  async start() {}

  destroy() {
    this.destroyed = true;
  }

  speak(samples = 16000) {
    this.options.onSpeechStart?.();
    this.options.onSpeechEnd(new Float32Array(samples));
  }

  // Simulates an in-progress utterance: speech start plus `samples` worth of
  // 512-sample VAD frames, without the closing speech end.
  speakFrames(samples) {
    this.options.onSpeechStart?.();
    this.emitFrames(samples);
  }

  emitFrames(samples) {
    for (let emitted = 0; emitted < samples; emitted += 512) {
      this.options.onFrameProcessed?.({}, new Float32Array(512));
    }
  }

  misfire() {
    this.options.onVADMisfire?.();
  }
}

function fakeVadModule() {
  return {
    MicVAD: {
      new: async (options) => new FakeVad(options),
    },
  };
}

module("Voice | Unit | Lib | subtitles", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    localStorage.removeItem("voice:subtitles");
    FakeWorker.instances = [];
    FakeVad.instances = [];

    this.captions = [];
    this.errors = [];
    this.progress = [];
    this.manager = new SubtitlesManager({
      onCaption: (roomId, userId, utterance) =>
        this.captions.push({ roomId, userId, ...utterance }),
      onLoadingChange: () => {},
      onProgress: (message) => this.progress.push(message),
      onError: (error) => this.errors.push(error),
      loadVad: async () => fakeVadModule(),
      createWorker: () => new FakeWorker(),
    });
  });

  hooks.afterEach(function () {
    this.manager.destroy();
    localStorage.removeItem("voice:subtitles");
  });

  test("attaching taps a stream and captions flow end to end", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));

    assert.strictEqual(FakeWorker.instances.length, 1, "one shared worker");
    assert.strictEqual(FakeVad.instances.length, 1, "one VAD per stream");

    FakeVad.instances[0].speak();
    await new Promise((resolve) => setTimeout(resolve, 10));

    assert.strictEqual(this.captions.length, 1);
    assert.propContains(this.captions[0], {
      roomId: 1,
      userId: 42,
      text: "hello world",
      final: true,
    });
    assert.strictEqual(
      FakeWorker.instances[0].jobs[0].userId,
      42,
      "the utterance is attributed to its speaker"
    );
  });

  test("captions carry the utterance's start wall-clock", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));
    const vad = FakeVad.instances[0];

    const before = Date.now();
    vad.speakFrames(3 * 16000);
    const after = Date.now();
    await new Promise((resolve) => setTimeout(resolve, 10));

    const interim = this.captions.at(-1);
    assert.false(interim.final);
    assert.true(
      interim.startedAt >= before,
      "the interim's start time is not earlier than the speech start"
    );
    assert.true(
      interim.startedAt <= after,
      "the interim's start time is not later than the speech start"
    );

    vad.options.onSpeechEnd(new Float32Array(4 * 16000));
    await new Promise((resolve) => setTimeout(resolve, 10));

    assert.strictEqual(
      this.captions.at(-1).startedAt,
      interim.startedAt,
      "the final shares the interim's start time"
    );
  });

  test("no worker or taps are created while disabled", async function (assert) {
    await this.manager.attach(1, 42, createFakeStream("s1"));

    assert.strictEqual(FakeWorker.instances.length, 0);
    assert.strictEqual(FakeVad.instances.length, 0);
  });

  test("re-attaching the same track is a no-op, a new track rebuilds the tap", async function (assert) {
    this.manager.setEnabled(true);
    const stream = createFakeStream("s1", "track-a");
    await this.manager.attach(1, 42, stream);
    await this.manager.attach(1, 42, stream);

    assert.strictEqual(FakeVad.instances.length, 1, "same track reuses tap");

    await this.manager.attach(1, 42, createFakeStream("s1", "track-b"));

    assert.strictEqual(FakeVad.instances.length, 2, "new track rebuilds");
    assert.true(FakeVad.instances[0].destroyed, "old tap is torn down");
  });

  test("disable tears everything down and drops in-flight utterances", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));
    const vad = FakeVad.instances[0];

    this.manager.setEnabled(false);

    assert.true(vad.destroyed, "VAD destroyed");
    assert.true(FakeWorker.instances[0].terminated, "worker terminated");

    vad.speak();
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.deepEqual(this.captions, [], "stale utterances are ignored");
  });

  test("detachRoom only removes that room's taps", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));
    await this.manager.attach(2, 43, createFakeStream("s2"));

    this.manager.detachRoom(1);

    assert.true(FakeVad.instances[0].destroyed);
    assert.false(FakeVad.instances[1].destroyed);
  });

  test("a worker error surfaces once and terminates the worker", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));

    FakeWorker.instances[0].emit({ type: "error", message: "boom" });

    assert.strictEqual(this.errors.length, 1);
    assert.true(FakeWorker.instances[0].terminated);
  });

  test("a long in-progress utterance produces interim captions on a cadence", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));
    const vad = FakeVad.instances[0];
    const worker = FakeWorker.instances[0];

    // 3s of speech without a pause: past the 1s minimum and the 1.5s
    // interim cadence (twice).
    vad.speakFrames(3 * 16000);
    await new Promise((resolve) => setTimeout(resolve, 10));

    const interims = worker.jobs.filter((job) => job.interim);
    assert.true(interims.length >= 1, "provisional snapshots were sent");
    assert.false(
      this.captions.at(-1).final,
      "the caption is marked provisional"
    );

    vad.options.onSpeechEnd(new Float32Array(4 * 16000));
    await new Promise((resolve) => setTimeout(resolve, 10));

    const finals = worker.jobs.filter((job) => !job.interim);
    assert.strictEqual(finals.length, 1, "one final pass");
    assert.strictEqual(
      finals[0].utteranceId,
      interims[0].utteranceId,
      "final and interims share the utterance"
    );
    assert.propContains(this.captions.at(-1), {
      text: "hello world",
      final: true,
    });
  });

  test("a VAD misfire retracts the provisional caption", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));
    const vad = FakeVad.instances[0];

    vad.speakFrames(3 * 16000);
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.false(this.captions.at(-1).final);

    vad.misfire();

    assert.propContains(this.captions.at(-1), { text: null, final: true });
  });

  test("detaching flushes the speaker's queue and drops in-flight captions", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));
    const worker = FakeWorker.instances[0];

    // The caption for this utterance is still "in flight" (a microtask away)
    // when the tap is detached.
    FakeVad.instances[0].speak();
    this.manager.detach(1, 42);

    await new Promise((resolve) => setTimeout(resolve, 10));

    assert.deepEqual(this.captions, [], "stale caption is dropped");
    assert.propContains(
      worker.messages.at(-1),
      { type: "flush", roomId: 1, userId: 42 },
      "the worker is told to discard the speaker's queued jobs"
    );
  });

  test("a slow-throughput signal sheds interim passes until recovery", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(1, 42, createFakeStream("s1"));
    const vad = FakeVad.instances[0];
    const worker = FakeWorker.instances[0];

    worker.emit({ type: "throughput", slow: true });
    vad.speakFrames(4 * 16000);
    assert.deepEqual(
      worker.jobs.filter((job) => job.interim),
      [],
      "no provisional snapshots while the model is behind"
    );

    worker.emit({ type: "throughput", slow: false });
    vad.emitFrames(4 * 16000);
    assert.true(
      worker.jobs.filter((job) => job.interim).length >= 1,
      "provisional snapshots resume once throughput recovers"
    );

    vad.options.onSpeechEnd(new Float32Array(4 * 16000));
    assert.strictEqual(
      worker.jobs.filter((job) => !job.interim).length,
      1,
      "the final pass is never shed"
    );
  });

  test("short utterances still reach the worker with identity attached", async function (assert) {
    this.manager.setEnabled(true);
    await this.manager.attach(7, 9, createFakeStream("s1"));

    FakeVad.instances[0].speak(8000);

    const job = FakeWorker.instances[0].jobs[0];
    assert.strictEqual(job.roomId, 7);
    assert.strictEqual(job.userId, 9);
    assert.strictEqual(job.pcm.byteLength, 8000 * 4);
  });
});
