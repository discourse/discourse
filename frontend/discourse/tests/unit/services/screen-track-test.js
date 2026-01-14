import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | screen-track", function (hooks) {
  setupTest(hooks);

  test("consolidateTimings", async function (assert) {
    const tracker = this.owner.lookup("service:screen-track");

    tracker.consolidateTimings({ 1: 10, 2: 5 }, 10, 1);
    tracker.consolidateTimings({ 1: 5, 3: 1 }, 3, 1);
    const consolidated = tracker.consolidateTimings({ 1: 5, 3: 1, 4: 5 }, 3, 2);

    assert.deepEqual(
      consolidated,
      [
        { timings: { 1: 15, 2: 5, 3: 1 }, topicTime: 13, topicId: 1 },
        { timings: { 1: 5, 3: 1, 4: 5 }, topicTime: 3, topicId: 2 },
      ],
      "expecting consolidated timings to match correctly"
    );

    await tracker.sendNextConsolidatedTiming();

    assert.strictEqual(
      tracker.highestReadFromCache(2),
      4,
      "caches highest read post number for second topic"
    );
  });

  test("appEvent topic:timings-sent is triggered after posting consolidated timings", async function (assert) {
    const tracker = this.owner.lookup("service:screen-track");
    const appEvents = this.owner.lookup("service:app-events");

    appEvents.on("topic:timings-sent", () => {
      assert.step("sent");
    });

    tracker.consolidateTimings({ 1: 10, 2: 5 }, 10, 1);
    await tracker.sendNextConsolidatedTiming();

    await assert.verifySteps(["sent"]);
  });
});
