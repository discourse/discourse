import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import DAG from "discourse/lib/dag";

module("Unit | Lib | DAG", function (hooks) {
  setupTest(hooks);

  let dag;

  test("DAG.from should create a DAG instance from the provided entries", function (assert) {
    dag = DAG.from([
      ["key1", "value1", { after: "key2" }],
      ["key2", "value2", { before: "key3" }],
      ["key3", "value3", { before: "key1" }],
    ]);

    assert.ok(dag.has("key1"));
    assert.ok(dag.has("key2"));
    assert.ok(dag.has("key3"));

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key2", "key3", "key1"]);
  });

  test("should add items to the map", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    assert.ok(dag.has("key1"));
    assert.ok(dag.has("key2"));
    assert.ok(dag.has("key3"));

    // adding a new item
    assert.ok(
      dag.add("key4", "value4"),
      "adding an item returns true when the item is added"
    );
    assert.ok(dag.has("key4"));

    // adding an item that already exists
    assert.notOk(
      dag.add("key1", "value1"),
      "adding an item returns false when the item already exists"
    );
  });

  test("should call the method specified for onAddItem callback when an item is added", function (assert) {
    let called = 0;

    dag = new DAG({
      onAddItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    assert.equal(called, 1, "the callback was called");

    // it doesn't call the callback when the item already exists
    dag.add("key1", "value1");
    assert.equal(called, 1, "the callback was not called");
  });

  test("should remove an item from the map", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    let removed = dag.delete("key2");

    assert.ok(dag.has("key1"));
    assert.false(dag.has("key2"));
    assert.ok(dag.has("key3"));

    assert.ok(removed, "delete returns true when the item is removed");

    removed = dag.delete("key2");
    assert.notOk(removed, "delete returns false when the item doesn't exist");
  });

  test("should call the method specified for onDeleteItem callback when an item is removed", function (assert) {
    let called = 0;

    dag = new DAG({
      onDeleteItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    dag.delete("key1");
    assert.equal(called, 1, "the callback was called");

    // it doesn't call the callback when the item doesn't exist
    dag.delete("key1");
    assert.equal(called, 1, "the callback was not called");
  });

  test("should replace the value from an item in the map", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    // simply replacing the value
    let replaced = dag.replace("key2", "replaced-value2");

    assert.deepEqual(
      dag.resolve().map((entry) => entry.value),
      ["value1", "replaced-value2", "value3"],
      "replace allows simply replacing the value"
    );
    assert.ok(replaced, "replace returns true when the item is replaced");

    // also changing the position
    dag.replace("key2", "replaced-value2-again", { before: "key1" });

    assert.deepEqual(
      dag.resolve().map((entry) => entry.value),
      ["replaced-value2-again", "value1", "value3"],
      "replace also allows changing the position"
    );

    // replacing an item that doesn't exist
    replaced = dag.replace("key4", "replaced-value4");
    assert.notOk(replaced, "replace returns false when the item doesn't exist");
  });

  test("should call the method specified for onReplaceItem callback when an item is replaced", function (assert) {
    let called = 0;

    dag = new DAG({
      onReplaceItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    dag.replace("key1", "replaced-value1");
    assert.equal(called, 1, "the callback was called");

    // it doesn't call the callback when the item doesn't exist
    dag.replace("key2", "replaced-value2");
    assert.equal(called, 1, "the callback was not called");
  });

  test("should reposition an item in the map", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    let repositioned = dag.reposition("key3", { before: "key1" });
    assert.ok(
      repositioned,
      "reposition returns true when the item is repositioned"
    );

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key3", "key1", "key2"]);

    // repositioning an item that doesn't exist
    repositioned = dag.reposition("key4", { before: "key1" });
    assert.notOk(
      repositioned,
      "reposition returns false when the item doesn't exist"
    );
  });

  test("should call the method specified for onRepositionItem callback when an item is repositioned", function (assert) {
    let called = 0;

    dag = new DAG({
      onRepositionItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    dag.reposition("key1", { before: "key2" });
    assert.equal(called, 1, "the callback was called");

    // it doesn't call the callback when the item doesn't exist
    dag.reposition("key2", { before: "key1" });
    assert.equal(called, 1, "the callback was not called");
  });

  test("should return the entries in the map", function (assert) {
    const entries = [
      ["key1", "value1", { after: "key2" }],
      ["key2", "value2", { before: "key3" }],
      ["key3", "value3", { before: "key1" }],
    ];

    dag = DAG.from(entries);
    const dagEntries = dag.entries();

    entries.forEach((entry, index) => {
      assert.equal(dagEntries[index][0], entry[0], "the key is correct");
      assert.equal(dagEntries[index][1], entry[1], "the value is correct");
      assert.equal(
        dagEntries[index][2]["before"],
        entry[2]["before"],
        "the before position is correct"
      );
      assert.equal(
        dagEntries[index][2]["after"],
        entry[2]["after"],
        "the after position is correct"
      );
    });
  });

  test("should resolve the map in the correct order", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key1", "key2", "key3"]);
  });

  test("allows for custom before and after default positioning", function (assert) {
    dag = new DAG({ defaultPosition: { before: "key3", after: "key2" } });
    dag.add("key1", "value1", {});
    dag.add("key2", "value2", { after: "key1" });
    dag.add("key3", "value3", { after: "key2" });
    dag.add("key4", "value4");

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key1", "key2", "key4", "key3"]);

    // it also returns the positioning data for each entry
    assert.deepEqual(
      resolved.map((entry) => entry.position),
      [
        { before: undefined, after: undefined }, // {} from key1
        { before: undefined, after: "key1" }, // from key2
        { before: "key3", after: "key2" }, // from the defaultPosition applied to key4
        { before: undefined, after: "key2" }, // from key3
      ]
    );
  });

  test("should resolve only existing keys", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2", { before: "key1" });
    dag.add("key3", "value3");

    dag.delete("key1");

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key2", "key3"]);
  });

  test("throws on bad positioning", function (assert) {
    dag = new DAG();

    assert.throws(
      () => dag.add("key1", "value1", { before: "key1" }),
      /cycle detected/
    );
  });
});
