import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import WindowedListCoordinator from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";

function coordinator() {
  return new WindowedListCoordinator({
    engine: { hasValue: false, filter: "" },
    feedback: {},
    getListboxId: () => "listbox",
    isStaticModal: () => false,
    onStillLoading() {},
  });
}

function row(key) {
  return { key, isSkeleton: false, flags: {}, item: { id: key } };
}

/** An option element as the roving modifier reports it. */
function optionElement(key, index) {
  const element = document.createElement("li");
  element.dataset.optionKey = key;
  element.dataset.index = String(index);
  return element;
}

module("Unit | ui-kit | WindowedListCoordinator | kept row", function (hooks) {
  setupTest(hooks);

  const before = ["a", "b", "tail"].map(row);
  // A large page lands ahead of the last row, as when rows follow the source rows.
  const after = [
    row("a"),
    row("b"),
    ...Array.from({ length: 100 }, (_, index) => row(`new-${index}`)),
    row("tail"),
  ];

  test("the cursor row stays mounted by its key when rows shift ahead of it", function (assert) {
    const list = coordinator();
    list.trackActiveOption(optionElement("tail", before.length - 1));

    assert.deepEqual(
      list.mountedRows(after)([]),
      [after.length - 1],
      "the row now at the cursor's key is kept, not the row at its old index"
    );
  });

  test("a clicked row stays mounted by its key when rows shift ahead of it", function (assert) {
    const list = coordinator();
    list.trackActiveOption(optionElement("tail", before.length - 1), {
      pointer: true,
    });

    assert.deepEqual(
      list.mountedRows(after)([]),
      [after.length - 1],
      "a pointer press keeps its row even though it shows no highlight"
    );
  });

  test("the old index is kept when the cursor's row has left the list", function (assert) {
    const list = coordinator();
    list.trackActiveOption(optionElement("tail", 2));

    assert.deepEqual(
      list.mountedRows(["a", "b", "c", "d"].map(row))([]),
      [2],
      "without its key in the rows, the cursor keeps its position"
    );
  });
});
