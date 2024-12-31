import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import DAGMap from "discourse/lib/dag-map";

module("Unit | Lib | DAGMap", function (hooks) {
  setupTest(hooks);

  test("Insert order is preserved when there are no position hints", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");

    const sorted = dagMap.sort();

    assert.deepEqual(sorted, ["key1", "key2", "key3"]);
  });

  test("Items are positioned just after the specified item", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");
    dagMap.add("key4");
    dagMap.add("key5");

    dagMap.add("after_key3", null, { after: "key3" });
    dagMap.add("after_key1", null, { after: "key1" });

    const sorted = dagMap.sort();

    assert.deepEqual(sorted, [
      "key1",
      "after_key1",
      "key2",
      "key3",
      "after_key3",
      "key4",
      "key5",
    ]);
  });

  test("Items are positioned just before the specified item", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");
    dagMap.add("key4");
    dagMap.add("key5");

    dagMap.add("before_key4", null, { before: "key4" });
    dagMap.add("before_key2", null, { before: "key2" });

    const sorted = dagMap.sort();

    assert.deepEqual(sorted, [
      "key1",
      "before_key2",
      "key2",
      "key3",
      "before_key4",
      "key4",
      "key5",
    ]);
  });

  test("Items are positioned just after the specified item", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");
    dagMap.add("key4");
    dagMap.add("key5");

    dagMap.add("after_key4", null, { after: "key4" });
    dagMap.add("after_key2", null, { after: "key2" });
    dagMap.add("after_key1", null, { after: "key1" });

    const sorted = dagMap.sort();

    assert.deepEqual(sorted, [
      "key1",
      "after_key1",
      "key2",
      "after_key2",
      "key3",
      "key4",
      "after_key4",
      "key5",
    ]);
  });

  test("Combining before and after yield the expected results", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");
    dagMap.add("key4");
    dagMap.add("key5");

    dagMap.add("before_key4", null, { before: "key4" });
    dagMap.add("before_key2", null, { before: "key2" });
    dagMap.add("after_key4", null, { after: "key4" });
    dagMap.add("after_key2", null, { after: "key2" });
    dagMap.add("after_key1", null, { after: "key1" });

    const sorted = dagMap.sort();

    assert.deepEqual(sorted, [
      "key1",
      "after_key1",
      "before_key2",
      "key2",
      "after_key2",
      "key3",
      "before_key4",
      "key4",
      "after_key4",
      "key5",
    ]);
  });

  test("You can position an item after another one that has an `before` hint", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");
    dagMap.add("key4");
    dagMap.add("key5");

    dagMap.add("before_key4", null, { before: "key4" });
    dagMap.add("after_before_key4", null, { after: "before_key4" });
    dagMap.add("before_key3", null, { before: "key3" });
    dagMap.add("after_before_key3", null, { after: "before_key3" });

    const sorted = dagMap.sort();

    assert.deepEqual(sorted, [
      "key1",
      "key2",
      "before_key3",
      "after_before_key3",
      "key3",
      "before_key4",
      "after_before_key4",
      "key4",
      "key5",
    ]);
  });

  test("You can position an item before another one that has an `after` hint", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");
    dagMap.add("key4");
    dagMap.add("key5");

    dagMap.add("after_key4", null, {
      after: "key4",
    });
    dagMap.add("before_after_key4", null, {
      before: "after_key4",
    });
    dagMap.add("after_key1", null, {
      after: "key1",
    });
    dagMap.add("before_after_key1", null, {
      before: "after_key1",
    });
    const sorted = dagMap.sort();

    assert.deepEqual(sorted, [
      "key1",
      "before_after_key1",
      "after_key1",
      "key2",
      "key3",
      "key4",
      "before_after_key4",
      "after_key4",
      "key5",
    ]);
  });

  test("Items cascading `after` hints are positioned as expected", function (assert) {
    const dagMap = new DAGMap();
    dagMap.add("key1");
    dagMap.add("key2");
    dagMap.add("key3");
    dagMap.add("key4");
    dagMap.add("key5");

    dagMap.add("after_key4", null, {
      after: "key4",
    });
    dagMap.add("before_after_key4", null, {
      before: "after_key4",
    });
    dagMap.add("after_key1", null, {
      after: "key1",
    });
    dagMap.add("after_after_after_key1", null, {
      after: "after_after_key1",
    });
    dagMap.add("after_after_key1", null, {
      after: "after_key1",
    });
    dagMap.add("before_after_key1", null, {
      before: "after_key1",
    });
    const sorted = dagMap.sort();

    assert.deepEqual(sorted, [
      "key1",
      "before_after_key1",
      "after_key1",
      "after_after_key1",
      "after_after_after_key1",
      "key2",
      "key3",
      "key4",
      "before_after_key4",
      "after_key4",
      "key5",
    ]);
  });

  test("It doesn't freak out when there are no items", function (assert) {
    const dagMap = new DAGMap();
    const sorted = dagMap.sort();

    assert.deepEqual(sorted, []);
  });
});
