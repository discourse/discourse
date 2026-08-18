import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

async function externalDragEvent(type, dataTransfer) {
  const event = new Event(type, { bubbles: true, cancelable: true });
  Object.assign(event, {
    clientX: 1,
    clientY: 1,
    dataTransfer,
    relatedTarget: null,
  });
  document.body.dispatchEvent(event);
  await new Promise((resolve) => requestAnimationFrame(resolve));
}

function externalTextDataTransfer() {
  const dataTransfer = new DataTransfer();
  dataTransfer.setData("text/plain", "external payload");
  return dataTransfer;
}

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
    assert.false(
      this.dragAndDrop.accepts([]),
      "and so does an empty list: the caller has not decided"
    );
  });

  test("tracks and filters an external drag", async function (assert) {
    const dataTransfer = externalTextDataTransfer();

    await externalDragEvent("dragenter", dataTransfer);

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

    await externalDragEvent("drop", dataTransfer);

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
    const dataTransfer = externalTextDataTransfer();

    Object.defineProperty(this.dragAndDrop, "isDestroying", {
      configurable: true,
      value: true,
    });
    await externalDragEvent("dragenter", dataTransfer);

    assert.false(
      Boolean(this.dragAndDrop.currentExternalDrag),
      "a destroying service does not record a newly-started external drag"
    );

    delete this.dragAndDrop.isDestroying;
    await externalDragEvent("drop", dataTransfer);
  });

  test("external monitor ignores drop after service destruction begins", async function (assert) {
    const dataTransfer = externalTextDataTransfer();
    await externalDragEvent("dragenter", dataTransfer);
    const externalDrag = this.dragAndDrop.currentExternalDrag;

    assert.true(
      Boolean(externalDrag),
      "the service records the external drag before destruction"
    );

    // Stubbed rather than really destroyed, as the sibling test does: a real
    // destroy also tears the monitor down, so the drop would be ignored even if
    // the guard under test were missing.
    Object.defineProperty(this.dragAndDrop, "isDestroying", {
      configurable: true,
      value: true,
    });
    await externalDragEvent("drop", dataTransfer);

    assert.strictEqual(
      this.dragAndDrop.currentExternalDrag,
      externalDrag,
      "a destroying service ignores the in-flight external drag's drop callback"
    );

    delete this.dragAndDrop.isDestroying;
  });
});
