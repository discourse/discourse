import { module, test } from "qunit";
import {
  isReservedArgName,
  RESERVED_ARG_NAMES,
  safeStringifyConfig,
} from "discourse/lib/blocks/config-validation";

module("Unit | Lib | blocks/config-validation", function () {
  module("RESERVED_ARG_NAMES", function () {
    test("includes expected reserved names", function (assert) {
      assert.true(RESERVED_ARG_NAMES.includes("classNames"));
      assert.true(RESERVED_ARG_NAMES.includes("outletName"));
      assert.true(RESERVED_ARG_NAMES.includes("children"));
      assert.true(RESERVED_ARG_NAMES.includes("conditions"));
      assert.true(RESERVED_ARG_NAMES.includes("$block$"));
    });

    test("is frozen", function (assert) {
      assert.true(Object.isFrozen(RESERVED_ARG_NAMES));
    });
  });

  module("isReservedArgName", function () {
    test("returns true for explicitly reserved names", function (assert) {
      assert.true(isReservedArgName("classNames"));
      assert.true(isReservedArgName("outletName"));
      assert.true(isReservedArgName("children"));
      assert.true(isReservedArgName("conditions"));
      assert.true(isReservedArgName("$block$"));
    });

    test("returns true for names starting with underscore", function (assert) {
      assert.true(isReservedArgName("_private"));
      assert.true(isReservedArgName("_internalState"));
      assert.true(isReservedArgName("_"));
      assert.true(isReservedArgName("__doubleUnderscore"));
    });

    test("returns false for regular names", function (assert) {
      assert.false(isReservedArgName("title"));
      assert.false(isReservedArgName("description"));
      assert.false(isReservedArgName("user"));
      assert.false(isReservedArgName("myCustomArg"));
    });

    test("returns false for names containing but not starting with underscore", function (assert) {
      assert.false(isReservedArgName("my_arg"));
      assert.false(isReservedArgName("some_value_here"));
    });
  });

  module("safeStringifyConfig", function () {
    test("stringifies simple primitives", function (assert) {
      assert.strictEqual(safeStringifyConfig(null), "null");
      assert.strictEqual(safeStringifyConfig(undefined), "undefined");
      assert.strictEqual(safeStringifyConfig(123), "123");
      assert.strictEqual(safeStringifyConfig(true), "true");
      assert.strictEqual(safeStringifyConfig(false), "false");
    });

    test("stringifies strings with quotes", function (assert) {
      assert.strictEqual(safeStringifyConfig("hello"), '"hello"');
      assert.strictEqual(safeStringifyConfig(""), '""');
    });

    test("truncates long strings", function (assert) {
      const longString = "a".repeat(50);
      const result = safeStringifyConfig(longString);
      assert.true(result.includes("..."));
      assert.true(result.length < longString.length + 10);
    });

    test("stringifies empty objects and arrays", function (assert) {
      assert.strictEqual(safeStringifyConfig({}), "{}");
      assert.strictEqual(safeStringifyConfig([]), "[]");
    });

    test("stringifies simple objects", function (assert) {
      const result = safeStringifyConfig({ name: "test", count: 42 });
      assert.true(result.includes("name:"));
      assert.true(result.includes('"test"'));
      assert.true(result.includes("count:"));
      assert.true(result.includes("42"));
    });

    test("stringifies arrays with items", function (assert) {
      const result = safeStringifyConfig([1, 2, 3]);
      assert.strictEqual(result, "[1, 2, 3]");
    });

    test("truncates arrays with more than 3 items", function (assert) {
      const result = safeStringifyConfig([1, 2, 3, 4, 5]);
      assert.true(result.includes("1"));
      assert.true(result.includes("2"));
      assert.true(result.includes("3"));
      assert.true(result.includes("... 2 more"));
    });

    test("truncates objects with more than 5 keys", function (assert) {
      const result = safeStringifyConfig({
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
      const result = safeStringifyConfig(nested, 2);
      assert.true(result.includes("level1:"));
      assert.true(result.includes("level2:"));
      assert.true(result.includes("[...]"));
    });

    test("handles circular references", function (assert) {
      const circular = { name: "root" };
      circular.self = circular;

      const result = safeStringifyConfig(circular);
      assert.true(result.includes("[Circular]"));
    });

    test("stringifies functions", function (assert) {
      function namedFunction() {}
      const result = safeStringifyConfig(namedFunction);
      assert.strictEqual(result, "[Function: namedFunction]");
    });

    test("stringifies anonymous functions", function (assert) {
      const result = safeStringifyConfig(() => {});
      assert.true(result.includes("[Function:"));
    });

    test("stringifies symbols", function (assert) {
      const result = safeStringifyConfig(Symbol("test"));
      assert.strictEqual(result, "[Symbol: test]");
    });

    test("respects maxLength parameter", function (assert) {
      const obj = { a: "very long value", b: "another value", c: "more" };
      const result = safeStringifyConfig(obj, 2, 30);
      assert.true(result.length <= 33); // 30 + "..."
      assert.true(result.endsWith("..."));
    });

    test("handles objects with null prototype", function (assert) {
      const obj = Object.create(null);
      obj.key = "value";

      const result = safeStringifyConfig(obj);
      assert.true(result.includes("key:"));
      assert.true(result.includes('"value"'));
    });

    test("handles mixed nested structures", function (assert) {
      const config = {
        block: "my-block",
        args: { title: "Hello", count: 5 },
        conditions: [{ type: "user", loggedIn: true }],
      };

      const result = safeStringifyConfig(config);
      assert.true(result.includes("block:"));
      assert.true(result.includes("args:"));
      assert.true(result.includes("conditions:"));
    });
  });
});
