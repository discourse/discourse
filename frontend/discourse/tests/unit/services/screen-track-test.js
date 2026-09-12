import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, {
  middlewareRateLimit,
  response,
} from "discourse/tests/helpers/create-pretender";

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

  test("keeps re-queuing timings once the failure delays are exhausted", async function (assert) {
    const tracker = this.owner.lookup("service:screen-track");
    pretender.post("/topics/timings", () => response(500, {}));

    tracker.consolidateTimings({ 1: 10 }, 10, 1);

    for (let attempt = 0; attempt < 6; attempt++) {
      tracker._blockSendingToServerTill = null;
      await tracker.sendNextConsolidatedTiming();
    }

    assert.deepEqual(
      tracker._consolidatedTimings,
      [{ timings: { 1: 10 }, topicTime: 10, topicId: 1 }],
      "the read timings are never dropped"
    );
  });

  test("waits the advertised Retry-After before sending timings again", async function (assert) {
    const tracker = this.owner.lookup("service:screen-track");
    pretender.post("/topics/timings", () => middlewareRateLimit(60));

    tracker.consolidateTimings({ 1: 10 }, 10, 1);
    const before = Date.now();
    await tracker.sendNextConsolidatedTiming();

    assert.true(
      tracker._blockSendingToServerTill - before >= 60000,
      "the server's Retry-After beats the local backoff ladder"
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
