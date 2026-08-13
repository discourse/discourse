import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | drag-and-drop", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.dragAndDrop = getOwner(this).lookup("service:drag-and-drop");
  });

  test("setCurrentDrag / clearCurrentDrag round-trip", function (assert) {
    assert.strictEqual(
      this.dragAndDrop.currentDrag,
      null,
      "nothing is in flight before a drag starts"
    );
    this.dragAndDrop.setCurrentDrag({
      type: "row",
      data: { id: 1 },
      element: document.body,
    });
    assert.deepEqual(
      this.dragAndDrop.currentDrag.data,
      { id: 1 },
      "the payload is readable while the drag is in flight"
    );
    this.dragAndDrop.clearCurrentDrag();
    assert.strictEqual(
      this.dragAndDrop.currentDrag,
      null,
      "clearing returns the service to its resting state"
    );
  });

  test("accepts matches a single type", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      type: "row",
      data: {},
      element: null,
    });
    assert.true(
      this.dragAndDrop.accepts("row"),
      "the in-flight type is accepted"
    );
    assert.false(
      this.dragAndDrop.accepts("card"),
      "a different type is rejected"
    );
  });

  test("accepts matches against an array of types", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      type: "card",
      data: {},
      element: null,
    });
    assert.true(
      this.dragAndDrop.accepts(["row", "card"]),
      "a list containing the in-flight type is accepted"
    );
    assert.false(
      this.dragAndDrop.accepts(["other"]),
      "a list without it is rejected"
    );
  });

  test("accepts is false when nothing is in flight", function (assert) {
    assert.false(
      this.dragAndDrop.accepts("row"),
      "no drag in flight accepts no single type"
    );
    assert.false(
      this.dragAndDrop.accepts(["a", "b"]),
      "and accepts no list either"
    );
  });

  test("accepts is false when no filter is supplied", function (assert) {
    this.dragAndDrop.setCurrentDrag({
      type: "row",
      data: {},
      element: null,
    });
    assert.false(
      this.dragAndDrop.accepts(null),
      "a null filter accepts nothing rather than everything"
    );
    assert.false(
      this.dragAndDrop.accepts(undefined),
      "an omitted filter accepts nothing either"
    );
  });
});
