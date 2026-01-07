import { module, test } from "qunit";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";

module("Unit | Blocks | Conditions | decorator", function () {
  module("config validation", function () {
    test("throws for missing type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            validArgKeys: [],
          }),
        /`type` is required and must be a string/
      );
    });

    test("throws for non-string type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: 123,
            validArgKeys: [],
          }),
        /`type` is required and must be a string/
      );
    });

    test("throws for missing validArgKeys", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
          }),
        /`validArgKeys` must be an array/
      );
    });

    test("throws for non-array validArgKeys", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            validArgKeys: "not-an-array",
          }),
        /`validArgKeys` must be an array/
      );
    });

    test("throws when source is included in validArgKeys", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            validArgKeys: ["foo", "source", "bar"],
          }),
        /Do not include 'source' in validArgKeys/
      );
    });
  });

  module("sourceType validation", function () {
    test("accepts valid sourceType values", function (assert) {
      const validSourceTypes = ["none", "outletArgs", "object"];

      for (const sourceType of validSourceTypes) {
        const decorator = blockCondition({
          type: `test-${sourceType}`,
          sourceType,
          validArgKeys: [],
        });

        @decorator
        class TestCondition extends BlockCondition {
          evaluate() {
            return true;
          }
        }

        assert.strictEqual(
          TestCondition.sourceType,
          sourceType,
          `sourceType "${sourceType}" should be accepted`
        );
      }
    });

    test("throws for invalid sourceType with suggestion", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            sourceType: "outletarg",
            validArgKeys: [],
          }),
        /Invalid `sourceType`.*"outletarg".*did you mean.*"outletArgs"/
      );
    });

    test("throws for completely invalid sourceType", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            sourceType: "invalid",
            validArgKeys: [],
          }),
        /Invalid `sourceType`.*Valid values are: none, outletArgs, object/
      );
    });

    test("defaults to 'none' when sourceType is not provided", function (assert) {
      @blockCondition({
        type: "test-default-source",
        validArgKeys: [],
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.sourceType, "none");
    });
  });

  module("unknown config keys validation", function () {
    test("throws for unknown config key with suggestion", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            validArgKeys: [],
            sourceType: "none",
            validArgKey: [],
          }),
        /Unknown config key.*"validArgKey".*did you mean.*"validArgKeys"/
      );
    });

    test("throws for multiple unknown config keys", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            validArgKeys: [],
            sourceTyp: "none",
            typo: true,
          }),
        /Unknown config key.*"sourceTyp".*"typo".*Valid keys are: type, sourceType, validArgKeys/
      );
    });

    test("throws for typo in sourceType key", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            validArgKeys: [],
            sourcetype: "outletArgs",
          }),
        /Unknown config key.*"sourcetype".*did you mean.*"sourceType"/
      );
    });

    test("accepts only valid config keys", function (assert) {
      @blockCondition({
        type: "test-valid-keys",
        sourceType: "outletArgs",
        validArgKeys: ["foo", "bar"],
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "test-valid-keys");
      assert.strictEqual(TestCondition.sourceType, "outletArgs");
      assert.deepEqual(TestCondition.validArgKeys, ["foo", "bar", "source"]);
    });
  });

  module("static property assignment", function () {
    test("assigns type as static getter", function (assert) {
      @blockCondition({
        type: "static-type-test",
        validArgKeys: [],
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "static-type-test");
    });

    test("assigns sourceType as static getter", function (assert) {
      @blockCondition({
        type: "static-source-test",
        sourceType: "object",
        validArgKeys: [],
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.sourceType, "object");
    });

    test("adds source to validArgKeys when sourceType is not none", function (assert) {
      @blockCondition({
        type: "source-key-test",
        sourceType: "outletArgs",
        validArgKeys: ["foo"],
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.validArgKeys, ["foo", "source"]);
    });

    test("does not add source to validArgKeys when sourceType is none", function (assert) {
      @blockCondition({
        type: "no-source-key-test",
        sourceType: "none",
        validArgKeys: ["foo"],
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.validArgKeys, ["foo"]);
    });

    test("freezes validArgKeys array", function (assert) {
      @blockCondition({
        type: "frozen-keys-test",
        validArgKeys: ["foo"],
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.true(Object.isFrozen(TestCondition.validArgKeys));
    });
  });
});
