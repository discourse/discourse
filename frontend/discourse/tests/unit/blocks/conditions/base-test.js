import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { BlockCondition } from "discourse/blocks/conditions";

module("Unit | Blocks | Conditions | base", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.blocks = getOwner(this).lookup("service:blocks");
  });

  module("validateSource", function () {
    test("allows source to be undefined for all sourceTypes", function (assert) {
      class NoSourceCondition extends BlockCondition {
        static type = "no-source-test";
        static sourceType = "none";

        evaluate() {
          return true;
        }
      }

      class OutletArgsCondition extends BlockCondition {
        static type = "outlet-args-test";
        static sourceType = "outletArgs";

        evaluate() {
          return true;
        }
      }

      class ObjectCondition extends BlockCondition {
        static type = "object-test";
        static sourceType = "object";

        evaluate() {
          return true;
        }
      }

      const noSource = new NoSourceCondition();
      const outletArgs = new OutletArgsCondition();
      const objectSource = new ObjectCondition();

      // None of these should throw when source is undefined
      assert.strictEqual(noSource.validate({}), undefined);
      assert.strictEqual(outletArgs.validate({}), undefined);
      assert.strictEqual(objectSource.validate({}), undefined);
    });

    test("throws when source is provided for sourceType 'none'", function (assert) {
      class NoSourceCondition extends BlockCondition {
        static type = "no-source-throw-test";
        static sourceType = "none";

        evaluate() {
          return true;
        }
      }

      const condition = new NoSourceCondition();

      assert.throws(
        () => condition.validate({ source: "@outletArgs.foo" }),
        /source.*parameter is not supported/
      );
    });

    test("validates source format for sourceType 'outletArgs'", function (assert) {
      class OutletArgsCondition extends BlockCondition {
        static type = "outlet-args-format-test";
        static sourceType = "outletArgs";

        evaluate() {
          return true;
        }
      }

      const condition = new OutletArgsCondition();

      // Valid formats should not throw
      assert.strictEqual(
        condition.validate({ source: "@outletArgs.foo" }),
        undefined
      );
      assert.strictEqual(
        condition.validate({ source: "@outletArgs.nested.path" }),
        undefined
      );
      assert.strictEqual(
        condition.validate({ source: "@outletArgs.deep.nested.value" }),
        undefined
      );

      // Invalid formats should throw
      assert.throws(
        () => condition.validate({ source: "foo" }),
        /must be in format "@outletArgs.propertyName"/
      );

      assert.throws(
        () => condition.validate({ source: "outletArgs.foo" }),
        /must be in format "@outletArgs.propertyName"/
      );

      assert.throws(
        () => condition.validate({ source: "@outletArgs" }),
        /must be in format "@outletArgs.propertyName"/
      );

      assert.throws(
        () => condition.validate({ source: 123 }),
        /must be a string/
      );
    });

    test("validates source is object for sourceType 'object'", function (assert) {
      class ObjectCondition extends BlockCondition {
        static type = "object-format-test";
        static sourceType = "object";

        evaluate() {
          return true;
        }
      }

      const condition = new ObjectCondition();

      // Valid objects should not throw
      assert.strictEqual(
        condition.validate({ source: { key: "value" } }),
        undefined
      );
      assert.strictEqual(condition.validate({ source: {} }), undefined);
      assert.strictEqual(condition.validate({ source: null }), undefined);

      // Invalid types should throw
      assert.throws(
        () => condition.validate({ source: "string" }),
        /must be an object/
      );

      assert.throws(
        () => condition.validate({ source: 123 }),
        /must be an object/
      );

      assert.throws(
        () => condition.validate({ source: true }),
        /must be an object/
      );
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
