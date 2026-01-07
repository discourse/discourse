import { module, test } from "qunit";
import {
  isReservedArgName,
  RESERVED_ARG_NAMES,
  safeStringifyConfig,
  VALID_CONFIG_KEYS,
  validateConfigKeys,
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

  module("VALID_CONFIG_KEYS", function () {
    test("includes expected config keys", function (assert) {
      assert.true(VALID_CONFIG_KEYS.includes("block"));
      assert.true(VALID_CONFIG_KEYS.includes("args"));
      assert.true(VALID_CONFIG_KEYS.includes("children"));
      assert.true(VALID_CONFIG_KEYS.includes("conditions"));
      assert.true(VALID_CONFIG_KEYS.includes("name"));
      assert.true(VALID_CONFIG_KEYS.includes("classNames"));
    });

    test("is frozen", function (assert) {
      assert.true(Object.isFrozen(VALID_CONFIG_KEYS));
    });

    test("has exactly 6 keys", function (assert) {
      assert.strictEqual(VALID_CONFIG_KEYS.length, 6);
    });
  });

  module("validateConfigKeys", function () {
    test("passes validation for config with all valid keys", function (assert) {
      const config = {
        block: "my-block",
        args: { title: "Hello" },
        children: [],
        conditions: [{ type: "user" }],
        name: "My Block",
        classNames: "custom-class",
      };

      // Should not throw
      validateConfigKeys(config, "test-outlet", "blocks[0]");
      assert.true(true, "validation passed without error");
    });

    test("passes validation for config with only required key", function (assert) {
      const config = { block: "my-block" };

      validateConfigKeys(config, "test-outlet", "blocks[0]");
      assert.true(true, "validation passed without error");
    });

    test("throws error for unknown key with suggestion for 'condition' typo", function (assert) {
      const config = {
        block: "my-block",
        condition: { type: "user" }, // typo: should be "conditions"
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) => {
          return (
            error.message.includes('"condition"') &&
            error.message.includes('did you mean "conditions"?') &&
            error.message.includes("test-outlet") &&
            error.message.includes("blocks[0]")
          );
        },
        "error message suggests correction and includes context"
      );
    });

    test("throws error for unknown key with suggestion for 'arg' typo", function (assert) {
      const config = {
        block: "my-block",
        arg: { title: "Hello" }, // typo: should be "args"
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) =>
          error.message.includes('"arg"') &&
          error.message.includes('did you mean "args"?'),
        "error message suggests 'args'"
      );
    });

    test("throws error for unknown key with suggestion for 'child' typo", function (assert) {
      const config = {
        block: "my-block",
        child: [], // typo: should be "children"
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) =>
          error.message.includes('"child"') &&
          error.message.includes('did you mean "children"?'),
        "error message suggests 'children'"
      );
    });

    test("throws error for unknown key with suggestion for 'className' typo", function (assert) {
      const config = {
        block: "my-block",
        className: "custom", // typo: should be "classNames"
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) =>
          error.message.includes('"className"') &&
          error.message.includes('did you mean "classNames"?'),
        "error message suggests 'classNames'"
      );
    });

    test("throws error for completely unknown key without suggestion", function (assert) {
      const config = {
        block: "my-block",
        foo: "bar", // unknown key - too different from any valid key
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) => {
          return (
            error.message.includes('"foo"') &&
            !error.message.includes("did you mean")
          );
        },
        "error message includes unknown key without suggestion"
      );
    });

    test("reports all unknown keys in single error message", function (assert) {
      const config = {
        block: "my-block",
        condition: { type: "user" }, // typo
        foo: "bar", // unknown
        arg: { title: "Hello" }, // typo
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) => {
          return (
            error.message.includes('did you mean "conditions"?') &&
            error.message.includes('did you mean "args"?') &&
            error.message.includes('"foo"')
          );
        },
        "error message includes all unknown keys with suggestions"
      );
    });

    test("fuzzy matching: 'codition' suggests 'conditions'", function (assert) {
      const config = {
        block: "my-block",
        codition: { type: "user" }, // 1 char different
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) =>
          error.message.includes('"codition"') &&
          error.message.includes('did you mean "conditions"?'),
        "fuzzy matching finds close match"
      );
    });

    test("fuzzy matching: 'conditons' (transposition) suggests 'conditions'", function (assert) {
      const config = {
        block: "my-block",
        conditons: { type: "user" }, // transposed 'o' and 'n'
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) =>
          error.message.includes('"conditons"') &&
          error.message.includes('did you mean "conditions"?'),
        "fuzzy matching handles transpositions"
      );
    });

    test("fuzzy matching: 'condtions' (missing char) suggests 'conditions'", function (assert) {
      const config = {
        block: "my-block",
        condtions: { type: "user" }, // missing 'i'
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) =>
          error.message.includes('"condtions"') &&
          error.message.includes('did you mean "conditions"?'),
        "fuzzy matching handles missing characters"
      );
    });

    test("singular/plural grammar: single key uses 'key'", function (assert) {
      const config = {
        block: "my-block",
        condition: {}, // one unknown key
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) => error.message.includes("Unknown config key "),
        "uses singular 'key' for one unknown key"
      );
    });

    test("singular/plural grammar: multiple keys uses 'keys'", function (assert) {
      const config = {
        block: "my-block",
        condition: {},
        arg: {}, // two unknown keys
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) => error.message.includes("Unknown config keys "),
        "uses plural 'keys' for multiple unknown keys"
      );
    });

    test("uses 'root' as path when path is not provided", function (assert) {
      const config = {
        block: "my-block",
        foo: "bar",
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet"),
        (error) => error.message.includes("block at root"),
        "error message uses 'root' as path"
      );
    });

    test("includes valid keys in error message", function (assert) {
      const config = {
        block: "my-block",
        unknown: "value",
      };

      assert.throws(
        () => validateConfigKeys(config, "test-outlet", "blocks[0]"),
        (error) => {
          return (
            error.message.includes("Valid keys are:") &&
            error.message.includes("block") &&
            error.message.includes("conditions")
          );
        },
        "error message lists valid keys"
      );
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
