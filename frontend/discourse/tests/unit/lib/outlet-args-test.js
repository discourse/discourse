import { module, test } from "qunit";
import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
import {
  _setIncludeDeprecatedArgsProperty,
  buildArgsWithDeprecations,
  DEPRECATED_ARGS_KEY,
} from "discourse/lib/outlet-args";

module("Unit | Lib | outlet-args", function (hooks) {
  hooks.afterEach(function () {
    _setIncludeDeprecatedArgsProperty(false);
  });

  module("buildArgsWithDeprecations", function () {
    test("combines args with deprecated args", function (assert) {
      const args = { topic: "topic-value" };
      const deprecatedArgs = {
        oldTopic: deprecatedOutletArgument({
          value: "old-topic-value",
          message: "Use 'topic' instead",
        }),
      };

      const result = buildArgsWithDeprecations(args, deprecatedArgs, {
        outletName: "test-outlet",
      });

      assert.strictEqual(result.topic, "topic-value", "regular arg is present");
      assert.strictEqual(
        Object.keys(result).length,
        2,
        "both args are enumerable"
      );
    });

    test("skips deprecated keys that already exist in args", function (assert) {
      const args = { topic: "current-value" };
      const deprecatedArgs = {
        topic: deprecatedOutletArgument({
          value: "deprecated-value",
          message: "This should be skipped",
        }),
      };

      const result = buildArgsWithDeprecations(args, deprecatedArgs, {
        outletName: "test-outlet",
      });

      assert.strictEqual(
        result.topic,
        "current-value",
        "uses value from args, not deprecatedArgs"
      );
      assert.strictEqual(
        Object.keys(result).length,
        1,
        "only one key is defined"
      );
    });

    test("does not include __deprecatedArgs__ by default", function (assert) {
      const args = { topic: "topic-value" };
      const deprecatedArgs = {
        oldTopic: deprecatedOutletArgument({ value: "old-value" }),
      };

      const result = buildArgsWithDeprecations(args, deprecatedArgs, {
        outletName: "test-outlet",
      });

      assert.strictEqual(
        result[DEPRECATED_ARGS_KEY],
        undefined,
        "__deprecatedArgs__ is not present by default"
      );
    });

    test("includes __deprecatedArgs__ when enabled", function (assert) {
      _setIncludeDeprecatedArgsProperty(true);

      const args = { topic: "topic-value" };
      const deprecatedArgs = {
        oldTopic: deprecatedOutletArgument({ value: "old-value" }),
      };

      const result = buildArgsWithDeprecations(args, deprecatedArgs, {
        outletName: "test-outlet",
      });

      assert.strictEqual(
        result[DEPRECATED_ARGS_KEY],
        deprecatedArgs,
        "__deprecatedArgs__ contains the raw deprecatedArgs object"
      );
    });

    test("__deprecatedArgs__ is non-enumerable", function (assert) {
      _setIncludeDeprecatedArgsProperty(true);

      const args = { topic: "topic-value" };
      const deprecatedArgs = {
        oldTopic: deprecatedOutletArgument({ value: "old-value" }),
      };

      const result = buildArgsWithDeprecations(args, deprecatedArgs, {
        outletName: "test-outlet",
      });

      assert.false(
        Object.keys(result).includes(DEPRECATED_ARGS_KEY),
        "__deprecatedArgs__ is not enumerable"
      );
      assert.strictEqual(
        result[DEPRECATED_ARGS_KEY],
        deprecatedArgs,
        "but it is still accessible"
      );
    });

    test("handles null/undefined args gracefully", function (assert) {
      const deprecatedArgs = {
        oldTopic: deprecatedOutletArgument({ value: "old-value" }),
      };

      const result = buildArgsWithDeprecations(null, deprecatedArgs, {
        outletName: "test-outlet",
      });

      assert.strictEqual(
        Object.keys(result).length,
        1,
        "only deprecated arg is present"
      );
    });

    test("handles null/undefined deprecatedArgs gracefully", function (assert) {
      const args = { topic: "topic-value" };

      const result = buildArgsWithDeprecations(args, null, {
        outletName: "test-outlet",
      });

      assert.strictEqual(result.topic, "topic-value", "regular arg is present");
      assert.strictEqual(Object.keys(result).length, 1, "only one arg present");
    });
  });
});
