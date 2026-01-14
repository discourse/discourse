import { module, test } from "qunit";
import { safeStringifyEntry } from "discourse/lib/blocks/entry-formatter";

module("Unit | Lib | blocks/entry-formatter", function () {
  module("safeStringifyEntry", function () {
    test("stringifies simple primitives", function (assert) {
      assert.strictEqual(safeStringifyEntry(null), "null");
      assert.strictEqual(safeStringifyEntry(undefined), "undefined");
      assert.strictEqual(safeStringifyEntry(123), "123");
      assert.strictEqual(safeStringifyEntry(true), "true");
      assert.strictEqual(safeStringifyEntry(false), "false");
    });

    test("stringifies strings with quotes", function (assert) {
      assert.strictEqual(safeStringifyEntry("hello"), '"hello"');
      assert.strictEqual(safeStringifyEntry(""), '""');
    });

    test("truncates long strings", function (assert) {
      const longString = "a".repeat(50);
      const result = safeStringifyEntry(longString);
      assert.true(result.includes("..."));
      assert.true(result.length < longString.length + 10);
    });

    test("stringifies empty objects and arrays", function (assert) {
      assert.strictEqual(safeStringifyEntry({}), "{}");
      assert.strictEqual(safeStringifyEntry([]), "[]");
    });

    test("stringifies simple objects", function (assert) {
      const result = safeStringifyEntry({ name: "test", count: 42 });
      assert.true(result.includes("name:"));
      assert.true(result.includes('"test"'));
      assert.true(result.includes("count:"));
      assert.true(result.includes("42"));
    });

    test("stringifies arrays with items", function (assert) {
      const result = safeStringifyEntry([1, 2, 3]);
      assert.strictEqual(result, "[1, 2, 3]");
    });

    test("truncates arrays with more than 3 items", function (assert) {
      const result = safeStringifyEntry([1, 2, 3, 4, 5]);
      assert.true(result.includes("1"));
      assert.true(result.includes("2"));
      assert.true(result.includes("3"));
      assert.true(result.includes("... 2 more"));
    });

    test("truncates objects with more than 5 keys", function (assert) {
      const result = safeStringifyEntry({
        a: 1,
        b: 2,
        c: 3,
        d: 4,
        e: 5,
        f: 6,
        g: 7,
      });
      assert.true(result.includes("..."));
    });

    test("handles nested objects up to maxDepth", function (assert) {
      const nested = { level1: { level2: { level3: "deep" } } };
      const result = safeStringifyEntry(nested, 2);
      assert.true(result.includes("level1:"));
      assert.true(result.includes("level2:"));
      assert.true(result.includes("[...]"));
    });

    test("handles circular references", function (assert) {
      const circular = { name: "root" };
      circular.self = circular;

      const result = safeStringifyEntry(circular);
      assert.true(result.includes("[Circular]"));
    });

    test("stringifies functions", function (assert) {
      function namedFunction() {}
      const result = safeStringifyEntry(namedFunction);
      assert.strictEqual(result, "[Function: namedFunction]");
    });

    test("stringifies anonymous functions", function (assert) {
      const result = safeStringifyEntry(() => {});
      assert.true(result.includes("[Function:"));
    });

    test("stringifies symbols", function (assert) {
      const result = safeStringifyEntry(Symbol("test"));
      assert.strictEqual(result, "[Symbol: test]");
    });

    test("respects maxLength parameter", function (assert) {
      const obj = { a: "very long value", b: "another value", c: "more" };
      const result = safeStringifyEntry(obj, 2, 30);
      assert.true(result.length <= 33); // 30 + "..."
      assert.true(result.endsWith("..."));
    });

    test("handles objects with null prototype", function (assert) {
      const obj = Object.create(null);
      obj.key = "value";

      const result = safeStringifyEntry(obj);
      assert.true(result.includes("key:"));
      assert.true(result.includes('"value"'));
    });

    test("handles mixed nested structures", function (assert) {
      const config = {
        block: "my-block",
        args: { title: "Hello", count: 5 },
        conditions: [{ type: "user", loggedIn: true }],
      };

      const result = safeStringifyEntry(config);
      assert.true(result.includes("block:"));
      assert.true(result.includes("args:"));
      assert.true(result.includes("conditions:"));
    });
  });
});
