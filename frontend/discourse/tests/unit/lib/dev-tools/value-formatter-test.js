import { module, test } from "qunit";
import {
  formatValue,
  getTypeInfo,
} from "discourse/static/dev-tools/lib/value-formatter";

module("Unit | Lib | dev-tools/value-formatter", function () {
  module("formatValue", function () {
    module("basic types", function () {
      test("formats null as literal", function (assert) {
        assert.strictEqual(formatValue(null), "null");
      });

      test("formats undefined as literal", function (assert) {
        assert.strictEqual(formatValue(undefined), "undefined");
      });

      test("formats numbers directly", function (assert) {
        assert.strictEqual(formatValue(42), "42");
        assert.strictEqual(formatValue(0), "0");
        assert.strictEqual(formatValue(-5.5), "-5.5");
        assert.strictEqual(formatValue(Infinity), "Infinity");
      });

      test("formats booleans directly", function (assert) {
        assert.strictEqual(formatValue(true), "true");
        assert.strictEqual(formatValue(false), "false");
      });
    });

    module("strings", function () {
      test("quotes strings", function (assert) {
        assert.strictEqual(formatValue("hello"), '"hello"');
        assert.strictEqual(formatValue(""), '""');
      });

      test("truncates long strings at 50 characters", function (assert) {
        const longString = "a".repeat(60);
        const result = formatValue(longString);

        assert.strictEqual(result, `"${"a".repeat(50)}..."`);
      });

      test("does not truncate strings at exactly 50 characters", function (assert) {
        const exactString = "a".repeat(50);
        const result = formatValue(exactString);

        assert.strictEqual(result, `"${exactString}"`);
      });
    });

    module("arrays", function () {
      test("shows array length by default", function (assert) {
        assert.strictEqual(formatValue([1, 2, 3]), "Array(3)");
        assert.strictEqual(formatValue([]), "Array(0)");
      });

      test("expands arrays when option is true", function (assert) {
        assert.strictEqual(
          formatValue([1, 2, 3], { expandArrays: true }),
          "[1, 2, 3]"
        );
      });

      test("expands nested arrays recursively", function (assert) {
        assert.strictEqual(
          formatValue([1, [2, 3]], { expandArrays: true }),
          "[1, [2, 3]]"
        );
      });

      test("formats array elements with quotes for strings", function (assert) {
        assert.strictEqual(
          formatValue(["a", "b"], { expandArrays: true }),
          '["a", "b"]'
        );
      });
    });

    module("objects", function () {
      test("shows constructor name for custom objects", function (assert) {
        class User {}
        const user = new User();

        assert.strictEqual(formatValue(user), "User {...}");
      });

      test("shows generic {...} for plain objects", function (assert) {
        assert.strictEqual(formatValue({}), "{...}");
        assert.strictEqual(formatValue({ foo: 1 }), "{...}");
      });
    });

    module("functions", function () {
      test("shows function name", function (assert) {
        function myFunction() {}
        assert.strictEqual(formatValue(myFunction), "fn myFunction()");
      });

      test("shows anonymous for unnamed functions", function (assert) {
        assert.strictEqual(
          formatValue(() => {}),
          "fn anonymous()"
        );
      });
    });

    module("symbols", function () {
      test("formats symbols when option is true", function (assert) {
        const sym = Symbol("test");
        assert.strictEqual(
          formatValue(sym, { handleSymbols: true }),
          "Symbol(test)"
        );
      });

      test("formats symbols without description", function (assert) {
        const sym = Symbol();
        assert.strictEqual(
          formatValue(sym, { handleSymbols: true }),
          "Symbol()"
        );
      });

      test("does not format symbols by default", function (assert) {
        const sym = Symbol("test");
        // Without handleSymbols, falls through to String(value)
        assert.strictEqual(formatValue(sym), "Symbol(test)");
      });
    });

    module("RegExp", function () {
      test("formats RegExp when option is true", function (assert) {
        const regex = /test/gi;
        assert.strictEqual(
          formatValue(regex, { handleRegExp: true }),
          "/test/gi"
        );
      });

      test("shows constructor name by default", function (assert) {
        const regex = /test/;
        assert.strictEqual(formatValue(regex), "RegExp {...}");
      });
    });
  });

  module("getTypeInfo", function () {
    test("returns 'null' for null", function (assert) {
      assert.strictEqual(getTypeInfo(null), "null");
    });

    test("returns 'undefined' for undefined", function (assert) {
      assert.strictEqual(getTypeInfo(undefined), "undefined");
    });

    test("returns 'array' for arrays", function (assert) {
      assert.strictEqual(getTypeInfo([]), "array");
      assert.strictEqual(getTypeInfo([1, 2, 3]), "array");
    });

    test("returns 'object' for objects", function (assert) {
      assert.strictEqual(getTypeInfo({}), "object");
      assert.strictEqual(getTypeInfo({ foo: 1 }), "object");
    });

    test("returns 'string' for strings", function (assert) {
      assert.strictEqual(getTypeInfo("hello"), "string");
      assert.strictEqual(getTypeInfo(""), "string");
    });

    test("returns 'number' for numbers", function (assert) {
      assert.strictEqual(getTypeInfo(42), "number");
      assert.strictEqual(getTypeInfo(0), "number");
      assert.strictEqual(getTypeInfo(-5.5), "number");
    });

    test("returns 'boolean' for booleans", function (assert) {
      assert.strictEqual(getTypeInfo(true), "boolean");
      assert.strictEqual(getTypeInfo(false), "boolean");
    });

    test("returns 'function' for functions", function (assert) {
      assert.strictEqual(
        getTypeInfo(() => {}),
        "function"
      );
      assert.strictEqual(
        getTypeInfo(function named() {}),
        "function"
      );
    });

    test("returns 'symbol' for symbols", function (assert) {
      assert.strictEqual(getTypeInfo(Symbol()), "symbol");
      assert.strictEqual(getTypeInfo(Symbol("test")), "symbol");
    });
  });
});
