import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  raiseBlockError,
  truncateForDisplay,
} from "discourse/lib/blocks/core/error";

module("Unit | Lib | blocks/core/error", function (hooks) {
  setupTest(hooks);

  module("raiseBlockError", function () {
    test("throws error in DEBUG mode", function (assert) {
      assert.throws(
        () => raiseBlockError("Test error message"),
        /\[Blocks\] Test error message/
      );
    });

    test("error message includes [Blocks] prefix", function (assert) {
      try {
        raiseBlockError("Custom error");
        assert.false(true, "Should have thrown");
      } catch (error) {
        assert.true(error.message.startsWith("[Blocks]"));
        assert.true(error.message.includes("Custom error"));
      }
    });

    test("preserves original message in error", function (assert) {
      const originalMessage = "Something went wrong with block registration";

      try {
        raiseBlockError(originalMessage);
        assert.false(true, "Should have thrown");
      } catch (error) {
        assert.true(error.message.includes(originalMessage));
      }
    });
  });
});

module("Unit | Lib | blocks/core/error > entry-formatter", function () {
  module("truncateForDisplay", function () {
    test("returns primitives unchanged", function (assert) {
      assert.strictEqual(truncateForDisplay(null), null);
      assert.strictEqual(truncateForDisplay(undefined), undefined);
      assert.strictEqual(truncateForDisplay(123), 123);
      assert.strictEqual(truncateForDisplay("hello"), "hello");
      assert.true(truncateForDisplay(true));
    });

    test("truncates deep objects at maxDepth", function (assert) {
      const deep = { a: { b: { c: { d: "deep" } } } };
      const result = truncateForDisplay(deep, 2);

      assert.deepEqual(result, { a: { b: "{...}" } });
    });

    test("truncates arrays at maxDepth", function (assert) {
      const deep = [[["nested"]]];
      const result = truncateForDisplay(deep, 2);

      assert.deepEqual(result, [["[...]"]]);
    });

    test("limits object keys to maxKeys", function (assert) {
      const obj = { a: 1, b: 2, c: 3, d: 4, e: 5, f: 6 };
      const result = truncateForDisplay(obj, 2, 3);

      assert.deepEqual(result, { a: 1, b: 2, c: 3, "...": "(3 more)" });
    });

    test("limits array items to maxKeys", function (assert) {
      const arr = [1, 2, 3, 4, 5, 6];
      const result = truncateForDisplay(arr, 2, 3);

      assert.deepEqual(result, [1, 2, 3, "..."]);
    });

    test("handles block key specially", function (assert) {
      const entry = { block: { blockName: "MyBlock" }, args: {} };
      const result = truncateForDisplay(entry);

      assert.strictEqual(result.block, "<MyBlock>");
    });

    test("handles children key specially", function (assert) {
      const entry = { block: {}, children: [{}, {}, {}] };
      const result = truncateForDisplay(entry);

      assert.strictEqual(result.children, "[3 children]");
    });

    test("handles circular references", function (assert) {
      const circular = { name: "root" };
      circular.self = circular;

      const result = truncateForDisplay(circular);

      assert.strictEqual(result.name, "root");
      assert.strictEqual(result.self, "[Circular]");
    });

    test("handles deeply nested circular references", function (assert) {
      const obj = { a: { b: {} } };
      obj.a.b.circular = obj;

      const result = truncateForDisplay(obj, 5);

      assert.strictEqual(result.a.b.circular, "[Circular]");
    });

    test("handles circular references in arrays", function (assert) {
      const arr = [1, 2];
      arr.push(arr);

      const result = truncateForDisplay(arr, 5);

      assert.strictEqual(result[0], 1);
      assert.strictEqual(result[1], 2);
      assert.strictEqual(result[2], "[Circular]");
    });

    test("handles empty objects and arrays", function (assert) {
      assert.deepEqual(truncateForDisplay({}), {});
      assert.deepEqual(truncateForDisplay([]), []);
    });

    test("handles mixed nested structures", function (assert) {
      const config = {
        block: { blockName: "TestBlock" },
        args: { title: "Hello" },
        children: [{ block: {} }],
      };

      const result = truncateForDisplay(config);

      assert.strictEqual(result.block, "<TestBlock>");
      assert.deepEqual(result.args, { title: "Hello" });
      assert.strictEqual(result.children, "[1 children]");
    });
  });
});
