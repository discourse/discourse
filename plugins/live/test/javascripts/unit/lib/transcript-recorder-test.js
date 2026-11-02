import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import TranscriptRecorder from "discourse/plugins/live/discourse/lib/live/transcript-recorder";

module("Live | Unit | Lib | transcript-recorder", function (hooks) {
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

  test("folds each user's reactions between utterances into one entry", function (assert) {
    this.recorder.start(1);
    this.recorder.recordReaction(1, 43, "bob", "clap", 1000);
    this.recorder.recordReaction(1, 44, "carol", "heart", 1100);
    this.recorder.recordReaction(1, 43, "bob", "clap", 1200);
    this.recorder.recordReaction(1, 43, "bob", "heart", 1300);
    this.recorder.record(1, 42, "alice", {
      id: 7,
      text: "thanks",
      final: true,
      startedAt: 2000,
    });
    this.recorder.recordReaction(1, 43, "bob", "clap", 3000);

    assert.deepEqual(
      this.recorder.entries.map((entry) => [
        entry.username,
        entry.text ?? entry.reactions,
      ]),
      [
        [
          "bob",
          [
            { emoji: "clap", count: 2 },
            { emoji: "heart", count: 1 },
          ],
        ],
        ["carol", [{ emoji: "heart", count: 1 }]],
        ["alice", "thanks"],
        ["bob", [{ emoji: "clap", count: 1 }]],
      ]
    );
  });

  test("ignores reactions from other rooms and while not recording", function (assert) {
    this.recorder.recordReaction(1, 43, "bob", "clap");
    this.recorder.start(1);
    this.recorder.recordReaction(2, 43, "bob", "clap");

    assert.deepEqual(this.recorder.entries, []);
  });
});
