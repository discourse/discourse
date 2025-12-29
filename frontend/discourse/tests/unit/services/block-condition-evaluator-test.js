import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  BlockCondition,
  BlockConditionValidationError,
} from "discourse/blocks/conditions";

module("Unit | Service | block-condition-evaluator", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.evaluator = getOwner(this).lookup("service:block-condition-evaluator");
  });

  module("built-in conditions", function () {
    test("registers built-in condition types", function (assert) {
      assert.true(this.evaluator.hasType("route"));
      assert.true(this.evaluator.hasType("user"));
      assert.true(this.evaluator.hasType("setting"));
      assert.true(this.evaluator.hasType("viewport"));
    });

    test("getRegisteredTypes returns all built-in types", function (assert) {
      const types = this.evaluator.getRegisteredTypes();
      assert.true(types.includes("route"));
      assert.true(types.includes("user"));
      assert.true(types.includes("setting"));
      assert.true(types.includes("viewport"));
    });
  });

  module("registerType", function () {
    test("registers a custom condition type", function (assert) {
      class BlockTestCondition extends BlockCondition {
        static type = "test-custom";

        evaluate() {
          return true;
        }
      }

      this.evaluator.registerType(BlockTestCondition);
      assert.true(this.evaluator.hasType("test-custom"));
    });

    test("throws if class does not extend BlockCondition", function (assert) {
      class NotACondition {
        static type = "not-a-condition";
      }

      assert.throws(
        () => this.evaluator.registerType(NotACondition),
        /must extend BlockCondition/
      );
    });

    test("throws if class does not define static type", function (assert) {
      class BlockNoTypeCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.throws(
        () => this.evaluator.registerType(BlockNoTypeCondition),
        /must define a static 'type' property/
      );
    });

    test("throws if type is already registered", function (assert) {
      class BlockDuplicateCondition extends BlockCondition {
        static type = "route";

        evaluate() {
          return true;
        }
      }

      assert.throws(
        () => this.evaluator.registerType(BlockDuplicateCondition),
        /already registered/
      );
    });
  });

  module("validate", function () {
    test("passes for null/undefined conditions", function (assert) {
      assert.strictEqual(this.evaluator.validate(null), undefined);
      assert.strictEqual(this.evaluator.validate(undefined), undefined);
    });

    test("throws for missing type", function (assert) {
      assert.throws(
        () => this.evaluator.validate({ foo: "bar" }),
        /missing "type" property/
      );
    });

    test("throws for unknown type", function (assert) {
      assert.throws(
        () => this.evaluator.validate({ type: "unknown-type" }),
        /Unknown block condition type/
      );
    });

    test("validates array of conditions (AND)", function (assert) {
      assert.throws(
        () =>
          this.evaluator.validate([
            { type: "user", loggedIn: true },
            { type: "unknown" },
          ]),
        /Unknown block condition type/
      );
    });

    test("validates 'any' combinator (OR)", function (assert) {
      assert.throws(
        () => this.evaluator.validate({ any: "not-an-array" }),
        /"any" must be an array of conditions/
      );

      assert.throws(
        () =>
          this.evaluator.validate({
            any: [{ type: "user" }, { type: "unknown" }],
          }),
        /Unknown block condition type/
      );
    });

    test("validates 'not' combinator", function (assert) {
      assert.throws(
        () => this.evaluator.validate({ not: [{ type: "user" }] }),
        /"not" must be a single condition object/
      );

      assert.throws(
        () => this.evaluator.validate({ not: { type: "unknown" } }),
        /Unknown block condition type/
      );
    });
  });

  module("evaluate", function () {
    test("returns true for null/undefined conditions", function (assert) {
      assert.true(this.evaluator.evaluate(null));
      assert.true(this.evaluator.evaluate(undefined));
    });

    test("returns false for unknown type", function (assert) {
      assert.false(this.evaluator.evaluate({ type: "unknown-type" }));
    });

    test("evaluates array of conditions with AND logic", function (assert) {
      class BlockAlwaysTrueCondition extends BlockCondition {
        static type = "always-true";

        evaluate() {
          return true;
        }
      }

      class BlockAlwaysFalseCondition extends BlockCondition {
        static type = "always-false";

        evaluate() {
          return false;
        }
      }

      this.evaluator.registerType(BlockAlwaysTrueCondition);
      this.evaluator.registerType(BlockAlwaysFalseCondition);

      assert.true(
        this.evaluator.evaluate([
          { type: "always-true" },
          { type: "always-true" },
        ])
      );

      assert.false(
        this.evaluator.evaluate([
          { type: "always-true" },
          { type: "always-false" },
        ])
      );
    });

    test("evaluates 'any' combinator with OR logic", function (assert) {
      class BlockAlwaysTrueCondition2 extends BlockCondition {
        static type = "always-true-2";

        evaluate() {
          return true;
        }
      }

      class BlockAlwaysFalseCondition2 extends BlockCondition {
        static type = "always-false-2";

        evaluate() {
          return false;
        }
      }

      this.evaluator.registerType(BlockAlwaysTrueCondition2);
      this.evaluator.registerType(BlockAlwaysFalseCondition2);

      assert.true(
        this.evaluator.evaluate({
          any: [{ type: "always-false-2" }, { type: "always-true-2" }],
        })
      );

      assert.false(
        this.evaluator.evaluate({
          any: [{ type: "always-false-2" }, { type: "always-false-2" }],
        })
      );
    });

    test("evaluates 'not' combinator", function (assert) {
      class BlockAlwaysTrueCondition3 extends BlockCondition {
        static type = "always-true-3";

        evaluate() {
          return true;
        }
      }

      class BlockAlwaysFalseCondition3 extends BlockCondition {
        static type = "always-false-3";

        evaluate() {
          return false;
        }
      }

      this.evaluator.registerType(BlockAlwaysTrueCondition3);
      this.evaluator.registerType(BlockAlwaysFalseCondition3);

      assert.false(this.evaluator.evaluate({ not: { type: "always-true-3" } }));
      assert.true(this.evaluator.evaluate({ not: { type: "always-false-3" } }));
    });

    test("passes args to condition evaluate method", function (assert) {
      let receivedArgs;

      class BlockArgCapturingCondition extends BlockCondition {
        static type = "arg-capturing";

        evaluate(args) {
          receivedArgs = args;
          return true;
        }
      }

      this.evaluator.registerType(BlockArgCapturingCondition);
      this.evaluator.evaluate({ type: "arg-capturing", foo: "bar", baz: 123 });

      assert.deepEqual(receivedArgs, { foo: "bar", baz: 123 });
    });
  });

  module("condition service injection", function () {
    test("conditions can inject services", function (assert) {
      let injectedSiteSettings;

      class BlockServiceInjectionCondition extends BlockCondition {
        static type = "service-injection-test";

        evaluate() {
          injectedSiteSettings = this.siteSettings;
          return true;
        }
      }

      // Manually inject service since we can't use decorator in test
      Object.defineProperty(
        BlockServiceInjectionCondition.prototype,
        "siteSettings",
        {
          get() {
            return getOwner(this).lookup("service:site-settings");
          },
        }
      );

      this.evaluator.registerType(BlockServiceInjectionCondition);
      this.evaluator.evaluate({ type: "service-injection-test" });

      assert.true(!!injectedSiteSettings, "siteSettings was injected");
      assert.strictEqual(typeof injectedSiteSettings.title, "string");
    });
  });
});

module("Unit | Conditions | BlockConditionValidationError", function () {
  test("has correct name property", function (assert) {
    const error = new BlockConditionValidationError("test message");
    assert.strictEqual(error.name, "BlockConditionValidationError");
    assert.strictEqual(error.message, "test message");
  });
});
