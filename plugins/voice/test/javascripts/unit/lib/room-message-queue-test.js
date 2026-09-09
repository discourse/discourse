import { module, test } from "qunit";
import RoomMessageQueue from "discourse/plugins/voice/discourse/lib/voice/room-message-queue";

module("Voice | Unit | Lib | room-message-queue", function () {
  test("continues processing later messages after a failure", async function (assert) {
    const queue = new RoomMessageQueue();
    const processed = [];

    const first = queue.enqueue("1", async () => {
      processed.push("first");
      throw new Error("boom");
    });

    const second = queue.enqueue("1", async () => {
      processed.push("second");
    });

    await Promise.allSettled([first, second]);

    assert.deepEqual(processed, ["first", "second"]);
  });

  test("keeps messages serialized per room", async function (assert) {
    const queue = new RoomMessageQueue();
    const processed = [];

    const first = queue.enqueue("1", async () => {
      await Promise.resolve();
      processed.push("first");
    });

    const second = queue.enqueue("1", async () => {
      processed.push("second");
    });

    await Promise.all([first, second]);

    assert.deepEqual(processed, ["first", "second"]);
  });
});
