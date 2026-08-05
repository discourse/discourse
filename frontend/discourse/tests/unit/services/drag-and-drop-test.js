import { destroy } from "@ember/destroyable";
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

    destroy(this.dragAndDrop);
    await externalDragEvent("drop", dataTransfer);

    assert.false(
      Boolean(this.dragAndDrop.currentExternalDrag !== externalDrag),
      "a destroying service ignores the in-flight external drag's drop callback"
    );
  });
});
