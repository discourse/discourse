import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import DAG from "discourse/lib/dag";

module("Unit | Lib | DAG", function (hooks) {
  setupTest(hooks);

  let dag;

  hooks.beforeEach(function () {
    dag = new DAG();
  });

  test("should add items to the map", function (assert) {
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    assert.ok(dag.has("key1"));
    assert.ok(dag.has("key2"));
    assert.ok(dag.has("key3"));
  });

  test("should remove an item from the map", function (assert) {
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    dag.delete("key2");

    assert.ok(dag.has("key1"));
    assert.notOk(dag.has("key2"));
    assert.ok(dag.has("key3"));
  });

  test("should reposition an item in the map", function (assert) {
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    dag.reposition("key3", { before: "key1" });

    const resolved = dag.resolve();
    const keys = resolved.map((pair) => pair.key);

    assert.deepEqual(keys, ["key3", "key1", "key2"]);
  });

  test("should resolve the map in the correct order", function (assert) {
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    const resolved = dag.resolve();
    const keys = resolved.map((pair) => pair.key);

    assert.deepEqual(keys, ["key1", "key2", "key3"]);
  });
});
