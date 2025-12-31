import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { raiseBlockError } from "discourse/lib/blocks/error";

module("Unit | Lib | blocks/error", function (hooks) {
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
      const originalMessage = "Something went wrong with block configuration";

      try {
        raiseBlockError(originalMessage);
        assert.false(true, "Should have thrown");
      } catch (error) {
        assert.true(error.message.includes(originalMessage));
      }
    });
  });
});
