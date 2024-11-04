import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import DAG from "discourse/lib/dag";

module("Unit | Lib | DAG", function (hooks) {
  setupTest(hooks);

  let dag;

  test("should add items to the map", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    assert.ok(dag.has("key1"));
    assert.ok(dag.has("key2"));
    assert.ok(dag.has("key3"));
  });

  test("should remove an item from the map", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    dag.delete("key2");

    assert.ok(dag.has("key1"));
    assert.false(dag.has("key2"));
    assert.ok(dag.has("key3"));
  });

  test("should reposition an item in the map", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    dag.reposition("key3", { before: "key1" });

    const resolved = dag.resolve();
    const keys = resolved.map((pair) => pair.key);

    assert.deepEqual(keys, ["key3", "key1", "key2"]);
  });

  test("should resolve the map in the correct order", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    const resolved = dag.resolve();
    const keys = resolved.map((pair) => pair.key);

    assert.deepEqual(keys, ["key1", "key2", "key3"]);
  });

  test("allows for custom before and after default positioning", function (assert) {
    dag = new DAG({ defaultPosition: { before: "key3", after: "key2" } });
    dag.add("key1", "value1", {});
    dag.add("key2", "value2", { after: "key1" });
    dag.add("key3", "value3", { after: "key2" });
    dag.add("key4", "value4");

    const resolved = dag.resolve();
    const keys = resolved.map((pair) => pair.key);

    assert.deepEqual(keys, ["key1", "key2", "key4", "key3"]);
  });

  test("should resolve only existing keys", function (assert) {
    dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2", { before: "key1" });
    dag.add("key3", "value3");

    dag.delete("key1");

    const resolved = dag.resolve();
    const keys = resolved.map((pair) => pair.key);

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
