import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import TranscriptRecorder from "discourse/plugins/voice/discourse/lib/voice/transcript-recorder";

module("Voice | Unit | Lib | transcript-recorder", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.changes = 0;
    this.recorder = new TranscriptRecorder({
      onChange: () => this.changes++,
    });
  });

  test("records final utterances with speaker and start time", function (assert) {
    this.recorder.start(1);
    this.recorder.record(1, 42, "alice", {
      id: 7,
      text: "hello world",
      final: true,
      startedAt: 1000,
    });

    assert.deepEqual(this.recorder.entries, [
      {
        utteranceId: 7,
        userId: 42,
        username: "alice",
        text: "hello world",
        startedAt: 1000,
      },
    ]);
  });

  test("ignores interims, other rooms, and captions while not recording", function (assert) {
    this.recorder.record(1, 42, "alice", {
      id: 1,
      text: "before start",
      final: true,
      startedAt: 1,
    });

    this.recorder.start(1);
    this.recorder.record(1, 42, "alice", {
      id: 2,
      text: "provisional",
      final: false,
      startedAt: 2,
    });
    this.recorder.record(2, 42, "alice", {
      id: 3,
      text: "other room",
      final: true,
      startedAt: 3,
    });

    assert.deepEqual(this.recorder.entries, []);
  });

  test("a null-text final withdraws the entry", function (assert) {
    this.recorder.start(1);
    this.recorder.record(1, 42, "alice", {
      id: 7,
      text: "oops",
      final: true,
      startedAt: 1000,
    });
    this.recorder.record(1, 42, "alice", { id: 7, text: null, final: true });

    assert.deepEqual(this.recorder.entries, []);
  });

  test("entries are ordered by utterance start, not arrival", function (assert) {
    this.recorder.start(1);
    // The shared worker serializes jobs, so with overlapping speakers the
    // later-started utterance can be transcribed first.
    this.recorder.record(1, 43, "bob", {
      id: 8,
      text: "second",
      final: true,
      startedAt: 2000,
    });
    this.recorder.record(1, 42, "alice", {
      id: 7,
      text: "first",
      final: true,
      startedAt: 1000,
    });

    assert.deepEqual(
      this.recorder.entries.map((entry) => entry.text),
      ["first", "second"]
    );
  });

  test("stop keeps the transcript, a new start discards it", function (assert) {
    this.recorder.start(1);
    this.recorder.record(1, 42, "alice", {
      id: 7,
      text: "kept",
      final: true,
      startedAt: 1000,
    });

    this.recorder.stop();
    assert.false(this.recorder.recording);
    assert.strictEqual(this.recorder.entries.length, 1, "entries survive stop");
    assert.strictEqual(
      this.recorder.entriesRoomId,
      1,
      "the entries' room survives stop"
    );

    this.recorder.record(1, 42, "alice", {
      id: 8,
      text: "after stop",
      final: true,
      startedAt: 2000,
    });
    assert.strictEqual(this.recorder.entries.length, 1, "stopped is stopped");

    this.recorder.start(1);
    assert.deepEqual(this.recorder.entries, [], "restart clears");
  });

  test("onChange fires for every mutation", function (assert) {
    this.recorder.start(1);
    this.recorder.record(1, 42, "alice", {
      id: 7,
      text: "hello",
      final: true,
      startedAt: 1000,
    });
    this.recorder.stop();

    assert.strictEqual(this.changes, 3);
  });
});
