import { module, test } from "qunit";
import WeakValueMap from "discourse/lib/weak-value-map";

/*
 * NOTE: Garbage collection behavior (WeakRef/FinalizationRegistry) cannot
 * be reliably tested since GC timing is non-deterministic. These tests
 * cover the synchronous Map-like API behavior only.
 */
module("Unit | Lib | weak-value-map", function () {
  test("set and get", function (assert) {
    const map = new WeakValueMap();
    const value = { id: 1 };

    map.set("key1", value);

    assert.strictEqual(map.get("key1"), value);
  });

  test("get returns undefined for missing keys", function (assert) {
    const map = new WeakValueMap();

    assert.strictEqual(map.get("nonexistent"), undefined);
  });

  test("has returns true for existing keys", function (assert) {
    const map = new WeakValueMap();
    const value = { id: 1 };

    map.set("key1", value);

    assert.true(map.has("key1"));
  });

  test("has returns false for missing keys", function (assert) {
    const map = new WeakValueMap();

    assert.false(map.has("nonexistent"));
  });

  test("delete removes entries", function (assert) {
    const map = new WeakValueMap();
    const value = { id: 1 };

    map.set("key1", value);
    const result = map.delete("key1");

    assert.true(result);
    assert.strictEqual(map.get("key1"), undefined);
    assert.false(map.has("key1"));
  });

  test("delete returns false for missing keys", function (assert) {
    const map = new WeakValueMap();

    assert.false(map.delete("nonexistent"));
  });

  test("clear removes all entries", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    map.set("key1", value1);
    map.set("key2", value2);
    map.clear();

    assert.strictEqual(map.size, 0);
    assert.false(map.has("key1"));
    assert.false(map.has("key2"));
  });

  test("size reflects entry count", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    assert.strictEqual(map.size, 0);

    map.set("key1", value1);
    assert.strictEqual(map.size, 1);

    map.set("key2", value2);
    assert.strictEqual(map.size, 2);

    map.delete("key1");
    assert.strictEqual(map.size, 1);
  });

  test("keys iterator yields all keys", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    map.set("key1", value1);
    map.set("key2", value2);

    const keys = [...map.keys()];

    assert.deepEqual(keys.sort(), ["key1", "key2"]);
  });

  test("values iterator yields all values", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    map.set("key1", value1);
    map.set("key2", value2);

    const values = [...map.values()];

    assert.strictEqual(values.length, 2);
    assert.true(values.includes(value1));
    assert.true(values.includes(value2));
  });

  test("entries iterator yields [key, value] pairs", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    map.set("key1", value1);
    map.set("key2", value2);

    const entries = [...map.entries()];

    assert.strictEqual(entries.length, 2);

    const entriesMap = new Map(entries);
    assert.strictEqual(entriesMap.get("key1"), value1);
    assert.strictEqual(entriesMap.get("key2"), value2);
  });

  test("forEach calls callback for each entry", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    map.set("key1", value1);
    map.set("key2", value2);

    const collected = [];
    map.forEach((value, key, mapRef) => {
      collected.push({ value, key });
      assert.strictEqual(mapRef, map);
    });

    assert.strictEqual(collected.length, 2);
  });

  test("forEach respects thisArg", function (assert) {
    const map = new WeakValueMap();
    const value = { id: 1 };
    const context = { name: "test-context" };

    map.set("key1", value);

    map.forEach(function () {
      assert.strictEqual(this, context);
    }, context);
  });

  test("Symbol.iterator works with for...of", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    map.set("key1", value1);
    map.set("key2", value2);

    const collected = [];
    for (const [key, value] of map) {
      collected.push({ key, value });
    }

    assert.strictEqual(collected.length, 2);
  });

  test("Symbol.toStringTag returns 'WeakValueMap'", function (assert) {
    const map = new WeakValueMap();

    assert.strictEqual(map[Symbol.toStringTag], "WeakValueMap");
    assert.strictEqual(
      Object.prototype.toString.call(map),
      "[object WeakValueMap]"
    );
  });

  test("set overwrites existing values", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    map.set("key1", value1);
    map.set("key1", value2);

    assert.strictEqual(map.get("key1"), value2);
    assert.strictEqual(map.size, 1);
  });

  test("set returns this for chaining", function (assert) {
    const map = new WeakValueMap();
    const value1 = { id: 1 };
    const value2 = { id: 2 };

    const result = map.set("key1", value1).set("key2", value2);

    assert.strictEqual(result, map);
    assert.strictEqual(map.size, 2);
  });
});
