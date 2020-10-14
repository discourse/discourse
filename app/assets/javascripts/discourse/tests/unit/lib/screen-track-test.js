import { test, module } from "qunit";
import ScreenTrack from "discourse/lib/screen-track";

module("lib:screen-track");

test("consolidateTimings", (assert) => {
  const tracker = new ScreenTrack();

  tracker.consolidateTimings({ 1: 10, 2: 5 }, 10, 1);
  tracker.consolidateTimings({ 1: 5, 3: 1 }, 3, 1);
  const consolidated = tracker.consolidateTimings({ 1: 5, 3: 1 }, 3, 2);

  assert.deepEqual(
    consolidated,
    [
      [{ 1: 5, 3: 1 }, 3, 2],
      [{ 1: 15, 2: 5, 3: 1 }, 13, 1],
    ],
    "expecting consolidated timings to match correctly"
  );
});
