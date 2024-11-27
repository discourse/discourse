import { module, test } from "qunit";
import { SWIPE_DIRECTIONS } from "discourse/lib/lightbox/constants";
import { getSwipeDirection } from "discourse/lib/lightbox/helpers";

module(
  "Unit | lib | Experimental Lightbox | Helpers | getSwipeDirection()",
  function () {
    test("returns the correct direction based on the difference between touchstart and touchend", function (assert) {
      assert.strictEqual(
        getSwipeDirection({
          touchstartX: 200,
          touchstartY: 0,
          touchendX: 50,
          touchendY: 0,
        }),
        SWIPE_DIRECTIONS.RIGHT,
        "returns 'RIGHT' for swipes with a large negative x-axis difference"
      );

      assert.strictEqual(
        getSwipeDirection({
          touchstartX: 50,
          touchstartY: 0,
          touchendX: 200,
          touchendY: 0,
        }),
        SWIPE_DIRECTIONS.LEFT,
        "returns 'LEFT' for swipes with a large positive x-axis difference"
      );

      assert.strictEqual(
        getSwipeDirection({
          touchstartX: 0,
          touchstartY: 200,
          touchendX: 0,
          touchendY: 50,
        }),
        SWIPE_DIRECTIONS.UP,
        "returns 'UP' for swipes with a large negative y-axis difference"
      );

      assert.strictEqual(
        getSwipeDirection({
          touchstartX: 0,
          touchstartY: 50,
          touchendX: 0,
          touchendY: 200,
        }),
        SWIPE_DIRECTIONS.DOWN,
        "returns 'DOWN' for swipes with a large positive y-axis difference"
      );

      assert.false(getSwipeDirection({
          touchstartX: 50,
          touchstartY: 50,
          touchendX: 49,
          touchendY: 49,
        }), "returns 'false' for swipes with a small x-axis difference and a small y-axis difference");
    });
  }
);
