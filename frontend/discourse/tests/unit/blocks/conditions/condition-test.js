import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { BlockCondition } from "discourse/blocks/conditions";
import { validateConditionSource } from "discourse/lib/blocks/condition-validation";

module("Unit | Blocks | Conditions | condition", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.blocks = getOwner(this).lookup("service:blocks");
  });

  module("validateConditionSource", function () {
    test("allows source to be undefined for all sourceTypes", function (assert) {
      assert.strictEqual(validateConditionSource("none", {}), null);
      assert.strictEqual(validateConditionSource("outletArgs", {}), null);
      assert.strictEqual(validateConditionSource("object", {}), null);
    });

    test("returns error when source is provided for sourceType 'none'", function (assert) {
      const error = validateConditionSource("none", {
        source: "@outletArgs.foo",
      });

      assert.true(error?.message.includes("source"));
      assert.true(error?.message.includes("not supported"));
      assert.strictEqual(error.path, "source");
    });

    test("validates source format for sourceType 'outletArgs'", function (assert) {
      // Valid formats should return null
      assert.strictEqual(
        validateConditionSource("outletArgs", { source: "@outletArgs.foo" }),
        null
      );
      assert.strictEqual(
        validateConditionSource("outletArgs", {
          source: "@outletArgs.nested.path",
        }),
        null
      );
      assert.strictEqual(
        validateConditionSource("outletArgs", {
          source: "@outletArgs.deep.nested.value",
        }),
        null
      );

      // Invalid formats should return errors with path
      let error = validateConditionSource("outletArgs", { source: "foo" });
      assert.true(
        error?.message.includes('must be in format "@outletArgs.propertyName"')
      );
      assert.strictEqual(error.path, "source");

      error = validateConditionSource("outletArgs", {
        source: "outletArgs.foo",
      });
      assert.true(
        error?.message.includes('must be in format "@outletArgs.propertyName"')
      );

      error = validateConditionSource("outletArgs", { source: "@outletArgs" });
      assert.true(
        error?.message.includes('must be in format "@outletArgs.propertyName"')
      );

      error = validateConditionSource("outletArgs", { source: 123 });
      assert.true(error?.message.includes("must be a string"));
    });

    test("validates source is object for sourceType 'object'", function (assert) {
      // Valid objects should return null
      assert.strictEqual(
        validateConditionSource("object", { source: { key: "value" } }),
        null
      );
      assert.strictEqual(
        validateConditionSource("object", { source: {} }),
        null
      );
      assert.strictEqual(
        validateConditionSource("object", { source: null }),
        null
      );

      // Invalid types should return errors
      let error = validateConditionSource("object", { source: "string" });
      assert.true(error?.message.includes("must be an object"));
      assert.strictEqual(error.path, "source");

      error = validateConditionSource("object", { source: 123 });
      assert.true(error?.message.includes("must be an object"));

      error = validateConditionSource("object", { source: true });
      assert.true(error?.message.includes("must be an object"));
    });
  });

  module("resolveSource", function () {
    test("returns undefined when source is not provided", function (assert) {
      class TestCondition extends BlockCondition {
        static type = "resolve-no-source-test";
        static sourceType = "outletArgs";

        evaluate() {
          return true;
        }
      }

      const condition = new TestCondition();
      assert.strictEqual(condition.resolveSource({}, {}), undefined);
    });

    test("returns source directly for sourceType 'object'", function (assert) {
      class ObjectCondition extends BlockCondition {
        static type = "resolve-object-test";
        static sourceType = "object";

        evaluate() {
          return true;
        }
      }

      const condition = new ObjectCondition();
      const sourceObj = { key: "value", nested: { deep: true } };

      assert.strictEqual(
        condition.resolveSource({ source: sourceObj }, {}),
        sourceObj
      );
    });

    test("resolves value from outlet args for sourceType 'outletArgs'", function (assert) {
      class OutletArgsCondition extends BlockCondition {
        static type = "resolve-outlet-args-test";
        static sourceType = "outletArgs";

        evaluate() {
          return true;
        }
      }

      const condition = new OutletArgsCondition();
      const context = {
        outletArgs: {
          topic: {
            id: 123,
            title: "Test Topic",
          },
          user: {
            admin: true,
          },
        },
      };

      // Simple path
      assert.deepEqual(
        condition.resolveSource({ source: "@outletArgs.topic" }, context),
        { id: 123, title: "Test Topic" }
      );

      // Nested path
      assert.strictEqual(
        condition.resolveSource({ source: "@outletArgs.topic.id" }, context),
        123
      );

      assert.true(
        condition.resolveSource({ source: "@outletArgs.user.admin" }, context)
      );
    });

    test("returns undefined for missing paths in outlet args", function (assert) {
      class OutletArgsCondition extends BlockCondition {
        static type = "resolve-missing-path-test";
        static sourceType = "outletArgs";

        evaluate() {
          return true;
        }
      }

      const condition = new OutletArgsCondition();
      const context = {
        outletArgs: {
          topic: { id: 123 },
        },
      };

      // Non-existent property
      assert.strictEqual(
        condition.resolveSource({ source: "@outletArgs.nonexistent" }, context),
        undefined
      );

      // Non-existent nested path
      assert.strictEqual(
        condition.resolveSource(
          { source: "@outletArgs.topic.missing.deep" },
          context
        ),
        undefined
      );

      // Missing outlet args entirely
      assert.strictEqual(
        condition.resolveSource({ source: "@outletArgs.topic" }, {}),
        undefined
      );
    });

    test("returns undefined for sourceType 'none'", function (assert) {
      class NoSourceCondition extends BlockCondition {
        static type = "resolve-none-test";
        static sourceType = "none";

        evaluate() {
          return true;
        }
      }

      const condition = new NoSourceCondition();

      assert.strictEqual(
        condition.resolveSource(
          { source: "@outletArgs.foo" },
          { outletArgs: { foo: "bar" } }
        ),
        undefined
      );
    });
  });

  module("evaluate", function () {
    test("throws when not implemented in subclass", function (assert) {
      class UnimplementedCondition extends BlockCondition {
        static type = "unimplemented-test";
      }

      const condition = new UnimplementedCondition();

      assert.throws(
        () => condition.evaluate({}, {}),
        /must implement evaluate/
      );
    });
  });

  module("getResolvedValueForLogging", function () {
    test("returns resolved source value when source is provided", function (assert) {
      class SourceCondition extends BlockCondition {
        static type = "logging-source-test";
        static sourceType = "outletArgs";

        evaluate() {
          return true;
        }
      }

      const condition = new SourceCondition();
      const context = {
        outletArgs: {
          topic: { id: 123 },
        },
      };

      const result = condition.getResolvedValueForLogging(
        { source: "@outletArgs.topic.id" },
        context
      );

      assert.deepEqual(result, { value: 123, hasValue: true });
    });

    test("returns undefined when source is not provided", function (assert) {
      class NoSourceLoggingCondition extends BlockCondition {
        static type = "logging-no-source-test";
        static sourceType = "outletArgs";

        evaluate() {
          return true;
        }
      }

      const condition = new NoSourceLoggingCondition();
      const result = condition.getResolvedValueForLogging({}, {});

      assert.strictEqual(result, undefined);
    });
  });
});
