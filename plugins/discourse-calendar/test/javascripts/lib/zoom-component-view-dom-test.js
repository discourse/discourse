import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { computeZoomViewSize } from "discourse/plugins/discourse-calendar/discourse/lib/zoom-component-view-dom";

function stubElement(width, parentWidth) {
  return {
    getBoundingClientRect: () => ({ width }),
    parentElement:
      parentWidth === undefined
        ? null
        : { getBoundingClientRect: () => ({ width: parentWidth }) },
  };
}

module("Unit | Lib | zoom-component-view-dom", function (hooks) {
  setupTest(hooks);

  test("sizes the video from the frame", function (assert) {
    assert.deepEqual(computeZoomViewSize(stubElement(1280)), {
      width: 1280,
      height: 720,
    });
  });

  test("falls back to the parent while the frame is still hidden", function (assert) {
    // A hidden frame measures zero, which would otherwise pin the video to its
    // minimum size for the rest of the meeting.
    assert.deepEqual(computeZoomViewSize(stubElement(0, 1280)), {
      width: 1280,
      height: 720,
    });
  });

  test("clamps to the minimum when nothing has been laid out", function (assert) {
    assert.deepEqual(computeZoomViewSize(stubElement(0, 0)), {
      width: 240,
      height: 135,
    });
  });

  test("clamps to the maximum", function (assert) {
    assert.deepEqual(computeZoomViewSize(stubElement(3000)), {
      width: 1440,
      height: 810,
    });
  });
});
