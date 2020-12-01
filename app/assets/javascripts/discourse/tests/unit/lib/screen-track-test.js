import { module, test } from "qunit";
import ScreenTrack from "discourse/lib/screen-track";

module("Unit | Utility | screen-track", function () {
  test("consolidateTimings", function (assert) {
    const tracker = new ScreenTrack();

    tracker.consolidateTimings({ 1: 10, 2: 5 }, 10, 1);
    tracker.consolidateTimings({ 1: 5, 3: 1 }, 3, 1);
    const consolidated = tracker.consolidateTimings({ 1: 5, 3: 1 }, 3, 2);

    assert.deepEqual(
      consolidated,
      [
        { timings: { 1: 15, 2: 5, 3: 1 }, topicTime: 13, topicId: 1 },
        { timings: { 1: 5, 3: 1 }, topicTime: 3, topicId: 2 },
      ],
      "expecting consolidated timings to match correctly"
    );
  });
});
