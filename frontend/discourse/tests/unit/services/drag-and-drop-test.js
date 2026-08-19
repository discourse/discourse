import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  dragEvent,
  textTransfer,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";

module("Unit | Service | drag-and-drop", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.dragAndDrop = getOwner(this).lookup("service:drag-and-drop");
  });

  test("accepts matches a single type or any of a list", function (assert) {
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
    assert.true(
      this.dragAndDrop.accepts(["card", "row"]),
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
    assert.false(
      this.dragAndDrop.accepts([]),
      "and so does an empty list: the caller has not decided"
    );
  });

  test("tracks and filters an external drag", async function (assert) {
    const dataTransfer = textTransfer("external payload");

    await dragEvent(document.body, "dragenter", {
      dataTransfer,
      clientX: 1,
      clientY: 1,
    });

    assert.true(this.dragAndDrop.isDragging, "an external drag is in flight");
    assert.true(
      this.dragAndDrop.currentExternalDrag.containsText(),
      "the decorated payload reports its native kind"
    );
    assert.strictEqual(
      this.dragAndDrop.currentExternalDrag.getText(),
      null,
      "the hover-time service snapshot does not claim access to string data the browser withholds until drop"
    );
    assert.true(
      this.dragAndDrop.acceptsExternal("text"),
      "the matching external vocabulary is accepted"
    );
    assert.false(
      this.dragAndDrop.acceptsExternal("files"),
      "a different external kind is rejected"
    );
    assert.true(
      this.dragAndDrop.acceptsExternal(["files", "text"]),
      "a list is accepted when any kind in it matches"
    );
    assert.false(
      this.dragAndDrop.acceptsExternal([]),
      "an empty list matches nothing, unlike a target's empty filter"
    );
    assert.false(
      this.dragAndDrop.acceptsExternal(null),
      "a null filter matches nothing"
    );
    assert.false(
      this.dragAndDrop.acceptsExternal(undefined),
      "an omitted filter matches nothing"
    );

    await dragEvent(document.body, "drop", {
      dataTransfer,
      clientX: 1,
      clientY: 1,
    });

    assert.strictEqual(
      this.dragAndDrop.currentExternalDrag,
      null,
      "the external payload is cleared after drop"
    );
    assert.false(
      this.dragAndDrop.isDragging,
      "the drag is no longer in flight"
    );
  });

  test("external monitor ignores drag start while service is destroying", async function (assert) {
    const dataTransfer = textTransfer("external payload");

    Object.defineProperty(this.dragAndDrop, "isDestroying", {
      configurable: true,
      value: true,
    });
    await dragEvent(document.body, "dragenter", {
      dataTransfer,
      clientX: 1,
      clientY: 1,
    });

    assert.false(
      Boolean(this.dragAndDrop.currentExternalDrag),
      "a destroying service does not record a newly-started external drag"
    );

    delete this.dragAndDrop.isDestroying;
    await dragEvent(document.body, "drop", {
      dataTransfer,
      clientX: 1,
      clientY: 1,
    });
  });

  test("external monitor ignores drop after service destruction begins", async function (assert) {
    const dataTransfer = textTransfer("external payload");
    await dragEvent(document.body, "dragenter", {
      dataTransfer,
      clientX: 1,
      clientY: 1,
    });
    const externalDrag = this.dragAndDrop.currentExternalDrag;

    assert.true(
      Boolean(externalDrag),
      "the service records the external drag before destruction"
    );

    // Stubbed, not destroyed: a real destroy also tears the monitor down, so the
    // drop would be ignored even without the guard under test.
    Object.defineProperty(this.dragAndDrop, "isDestroying", {
      configurable: true,
      value: true,
    });
    await dragEvent(document.body, "drop", {
      dataTransfer,
      clientX: 1,
      clientY: 1,
    });

    assert.strictEqual(
      this.dragAndDrop.currentExternalDrag,
      externalDrag,
      "a destroying service ignores the in-flight external drag's drop callback"
    );

    delete this.dragAndDrop.isDestroying;
  });
});
