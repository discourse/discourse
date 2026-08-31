import { module, test } from "qunit";
import {
  queuePosition,
  speakQueue,
} from "discourse/plugins/voice/discourse/lib/voice/speak-queue";

function stageRoom(participants) {
  return { room_type: "stage", active_participants: participants };
}

module("Voice | Unit | Lib | speak-queue", function () {
  test("orders raised hands by hand_raised_at ascending", function (assert) {
    const room = stageRoom([
      { id: 1, hand_raised_at: 300 },
      { id: 2, hand_raised_at: 100 },
      { id: 3, hand_raised_at: 200 },
    ]);

    assert.deepEqual(
      speakQueue(room).map((participant) => participant.id),
      [2, 3, 1],
      "the earliest raised hand comes first"
    );
  });

  test("breaks equal timestamps by numeric user id", function (assert) {
    const room = stageRoom([
      { id: "10", hand_raised_at: 100 },
      { id: "9", hand_raised_at: 100 },
    ]);

    assert.deepEqual(
      speakQueue(room).map((participant) => participant.id),
      ["9", "10"],
      "ids compare numerically, not lexicographically"
    );
  });

  test("excludes participants without a raised hand", function (assert) {
    const room = stageRoom([
      { id: 1 },
      { id: 2, hand_raised_at: 100 },
      { id: 3, hand_raised_at: null },
    ]);

    assert.deepEqual(
      speakQueue(room).map((participant) => participant.id),
      [2],
      "only participants with hand_raised_at enter the queue"
    );
  });

  test("returns an empty queue for non-stage rooms", function (assert) {
    const room = {
      room_type: "open",
      active_participants: [{ id: 1, hand_raised_at: 100 }],
    };

    assert.deepEqual(
      speakQueue(room),
      [],
      "raised hands are meaningless outside stage rooms"
    );
    assert.deepEqual(speakQueue(null), [], "a missing room yields no queue");
  });

  test("queuePosition returns the 1-based position in the queue", function (assert) {
    const room = stageRoom([
      { id: 1, hand_raised_at: 300 },
      { id: 2, hand_raised_at: 100 },
      { id: 3, hand_raised_at: 200 },
    ]);

    assert.strictEqual(queuePosition(room, 2), 1, "first raised hand is #1");
    assert.strictEqual(queuePosition(room, 1), 3, "latest raised hand is #3");
  });

  test("queuePosition is null for un-queued users and falsy user ids", function (assert) {
    const room = stageRoom([{ id: 1, hand_raised_at: 100 }, { id: 2 }]);

    assert.strictEqual(
      queuePosition(room, 2),
      null,
      "a participant without a raised hand has no position"
    );
    assert.strictEqual(
      queuePosition(room, 99),
      null,
      "a user outside the room has no position"
    );
    assert.strictEqual(
      queuePosition(room, null),
      null,
      "a falsy user id has no position"
    );
  });
});
