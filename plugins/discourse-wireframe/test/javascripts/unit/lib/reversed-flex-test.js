import { module, test } from "qunit";
import {
  flipPosition,
  isReversedFlexLayout,
} from "discourse/plugins/discourse-wireframe/discourse/lib/reversed-flex";

module("Unit | Discourse Wireframe | reversed-flex", function () {
  test("isReversedFlexLayout: true only for reversed stack / row", function (assert) {
    assert.true(isReversedFlexLayout({ mode: "stack", reverse: true }));
    assert.true(isReversedFlexLayout({ mode: "row", reverse: true }));
  });

  test("isReversedFlexLayout: false without reverse", function (assert) {
    assert.false(isReversedFlexLayout({ mode: "row" }));
    assert.false(isReversedFlexLayout({ mode: "stack", reverse: false }));
  });

  test("isReversedFlexLayout: false for grid / tiles even when reversed", function (assert) {
    assert.false(isReversedFlexLayout({ mode: "grid", reverse: true }));
    assert.false(isReversedFlexLayout({ mode: "tiles", reverse: true }));
    assert.false(
      isReversedFlexLayout({ mode: "free-grid", reverse: true }),
      "the legacy free-grid mode coerces to grid"
    );
  });

  test("isReversedFlexLayout: defaults missing mode to stack", function (assert) {
    assert.true(
      isReversedFlexLayout({ reverse: true }),
      "no mode means stack, which is a flex mode"
    );
  });

  test("isReversedFlexLayout: handles nullish args", function (assert) {
    assert.false(isReversedFlexLayout(null));
    assert.false(isReversedFlexLayout(undefined));
    assert.false(isReversedFlexLayout({}));
  });

  test("flipPosition swaps before/after", function (assert) {
    assert.strictEqual(flipPosition("before"), "after");
    assert.strictEqual(flipPosition("after"), "before");
  });
});
