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
      kind: "row",
      data: { id: 1 },
      sourceElement: document.body,
    });
    assert.deepEqual(this.dragAndDrop.currentDrag.data, { id: 1 });
    this.dragAndDrop.clearCurrentDrag();
    assert.strictEqual(this.dragAndDrop.currentDrag, null);
  });

  test("isAccepted matches a single kind", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      kind: "row",
      data: {},
      sourceElement: null,
    });
    assert.true(this.dragAndDrop.isAccepted("row"));
    assert.false(this.dragAndDrop.isAccepted("card"));
  });

  test("isAccepted matches against an array of kinds", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      kind: "card",
      data: {},
      sourceElement: null,
    });
    assert.true(this.dragAndDrop.isAccepted(["row", "card"]));
    assert.false(this.dragAndDrop.isAccepted(["other"]));
  });

  test("isAccepted is false when nothing is in flight", function (assert) {
    assert.false(this.dragAndDrop.isAccepted("row"));
    assert.false(this.dragAndDrop.isAccepted(["a", "b"]));
  });

  test("isAccepted is false when accepts is missing", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      kind: "row",
      data: {},
      sourceElement: null,
    });
    assert.false(this.dragAndDrop.isAccepted(null));
    assert.false(this.dragAndDrop.isAccepted(undefined));
  });
});
