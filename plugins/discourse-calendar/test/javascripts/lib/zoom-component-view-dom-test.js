import { module, test } from "qunit";
import { computeZoomViewSize } from "discourse/plugins/discourse-calendar/discourse/lib/zoom-component-view-dom";

function elementOfWidth(width) {
  return { getBoundingClientRect: () => ({ width }) };
}

module("Unit | Lib | zoom-component-view-dom", function () {
  test("computeZoomViewSize measures the root", function (assert) {
    assert.deepEqual(computeZoomViewSize(elementOfWidth(754)), {
      width: 754,
      height: 424,
    });
  });

  test("computeZoomViewSize falls back to the container when the root is collapsed", function (assert) {
    const root = {
      ...elementOfWidth(0),
      parentElement: elementOfWidth(754),
    };

    assert.deepEqual(
      computeZoomViewSize(root),
      { width: 754, height: 424 },
      "a root that has not been laid out yet does not pin Zoom to the minimum"
    );
  });

  test("computeZoomViewSize clamps to the supported range", function (assert) {
    assert.deepEqual(
      computeZoomViewSize(elementOfWidth(120)),
      { width: 240, height: 135 },
      "below the minimum"
    );

    assert.deepEqual(
      computeZoomViewSize(elementOfWidth(4000)),
      { width: 1440, height: 810 },
      "above the maximum"
    );

    assert.deepEqual(
      computeZoomViewSize(null),
      { width: 240, height: 135 },
      "without an element to measure"
    );
  });
});
