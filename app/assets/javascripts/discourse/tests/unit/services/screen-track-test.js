import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Service | screen-track", function () {
  test("consolidateTimings", async function (assert) {
    const tracker = this.container.lookup("service:screen-track");

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

    assert.equal(
      tracker.highestReadFromCache(2),
      4,
      "caches highest read post number for second topic"
    );
  });

  test("ScreenTrack has appEvents", async function (assert) {
    const tracker = this.container.lookup("service:screen-track");
    assert.ok(tracker.appEvents);
  });

  test("appEvent topic:timings-sent is triggered", async function (assert) {
    assert.timeout(1000);

    const tracker = this.container.lookup("service:screen-track");
    const appEvents = this.container.lookup("service:app-events");

    const done = assert.async();

    appEvents.on("topic:timings-sent", () => {
      assert.ok(true);
      done();
    });

    await tracker.sendNextConsolidatedTiming();
  });
});
