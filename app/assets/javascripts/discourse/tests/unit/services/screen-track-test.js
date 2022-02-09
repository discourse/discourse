import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Service | screen-track", function () {
  test("consolidateTimings", function (assert) {
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

    tracker.sendNextConsolidatedTiming();
    assert.equal(
      tracker.highestReadFromCache(2),
      4,
      "caches highest read post number for second topic"
    );
  });
});
