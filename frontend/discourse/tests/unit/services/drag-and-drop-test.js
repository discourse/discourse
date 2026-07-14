import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | drag-and-drop", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.dragAndDrop = getOwner(this).lookup("service:drag-and-drop");
  });

  test("setCurrentDrag / clearCurrentDrag round-trip", function (assert) {
    assert.strictEqual(this.dragAndDrop.currentDrag, null);
    this.dragAndDrop.setCurrentDrag({
      type: "row",
      data: { id: 1 },
      element: document.body,
    });
    assert.deepEqual(this.dragAndDrop.currentDrag.data, { id: 1 });
    this.dragAndDrop.clearCurrentDrag();
    assert.strictEqual(this.dragAndDrop.currentDrag, null);
  });

  test("accepts matches a single type", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      type: "row",
      data: {},
      element: null,
    });
    assert.true(this.dragAndDrop.accepts("row"));
    assert.false(this.dragAndDrop.accepts("card"));
  });

  test("accepts matches against an array of types", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      type: "card",
      data: {},
      element: null,
    });
    assert.true(this.dragAndDrop.accepts(["row", "card"]));
    assert.false(this.dragAndDrop.accepts(["other"]));
  });

  test("accepts is false when nothing is in flight", function (assert) {
    assert.false(this.dragAndDrop.accepts("row"));
    assert.false(this.dragAndDrop.accepts(["a", "b"]));
  });

  test("accepts is false when no filter is supplied", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      type: "row",
      data: {},
      element: null,
    });
    assert.false(this.dragAndDrop.accepts(null));
    assert.false(this.dragAndDrop.accepts(undefined));
  });
});
