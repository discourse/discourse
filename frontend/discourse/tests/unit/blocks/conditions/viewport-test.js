import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockViewportCondition from "discourse/blocks/conditions/viewport";
import { validateConditions } from "discourse/tests/helpers/block-testing";

module("Unit | Blocks | Condition | viewport", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockViewportCondition();
    setOwner(this.condition, getOwner(this));

    // Helper to validate via infrastructure
    this.validateCondition = (args) => {
      const conditionTypes = new Map([["viewport", this.condition]]);

      try {
        validateConditions({ type: "viewport", ...args }, conditionTypes);
        return null;
      } catch (error) {
        return error;
      }
    };
  });

  module("validate (through infrastructure)", function () {
    test("returns error for invalid min breakpoint (enum validation)", function (assert) {
      const error = this.validateCondition({ min: "xxl" });
      assert.true(
        error?.message.includes("must be one of"),
        "returns error for invalid enum"
      );
    });

    test("returns error for invalid max breakpoint (enum validation)", function (assert) {
      const error = this.validateCondition({ max: "invalid" });
      assert.true(error?.message.includes("must be one of"), "returns error");
    });

    test("returns error when min > max (custom validation)", function (assert) {
      const error = this.validateCondition({ min: "xl", max: "sm" });
      assert.true(error?.message.includes("larger than"), "returns error");
    });

    test("passes valid breakpoint configurations", function (assert) {
      assert.strictEqual(this.validateCondition({ min: "sm" }), null);
      assert.strictEqual(this.validateCondition({ max: "lg" }), null);
      assert.strictEqual(
        this.validateCondition({ min: "md", max: "xl" }),
        null
      );
      assert.strictEqual(this.validateCondition({ min: "2xl" }), null);
      assert.strictEqual(this.validateCondition({ touch: true }), null);
      assert.strictEqual(this.validateCondition({ touch: false }), null);
    });

    test("passes when min equals max", function (assert) {
      assert.strictEqual(
        this.validateCondition({ min: "md", max: "md" }),
        null
      );
    });

    test("returns error when min is not a string (schema type validation)", function (assert) {
      const error = this.validateCondition({ min: 123 });
      assert.true(error?.message.includes("must be a string"));
    });

    test("returns error when max is not a string (schema type validation)", function (assert) {
      const error = this.validateCondition({ max: true });
      assert.true(error?.message.includes("must be a string"));
    });

    test("returns error when touch is not a boolean (schema type validation)", function (assert) {
      const error = this.validateCondition({ touch: 1 });
      assert.true(error?.message.includes("must be a boolean"));
    });
  });

  module("evaluate", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.condition.capabilities = {
        touch: false,
        viewport: {
          sm: true,
          md: true,
          lg: false,
          xl: false,
          "2xl": false,
        },
      };
    });

    module("breakpoint conditions", function () {
      test("passes when viewport meets minimum breakpoint", function (assert) {
        assert.true(this.condition.evaluate({ min: "md" }));
      });

      test("passes when viewport exceeds minimum breakpoint", function (assert) {
        assert.true(this.condition.evaluate({ min: "sm" }));
      });

      test("fails when viewport is below minimum breakpoint", function (assert) {
        assert.false(this.condition.evaluate({ min: "lg" }));
      });

      test("passes when viewport meets maximum breakpoint", function (assert) {
        assert.true(this.condition.evaluate({ max: "md" }));
      });

      test("passes when viewport is below maximum breakpoint", function (assert) {
        assert.true(this.condition.evaluate({ max: "lg" }));
      });

      test("fails when viewport exceeds maximum breakpoint", function (assert) {
        this.condition.capabilities.viewport.lg = true;
        assert.false(this.condition.evaluate({ max: "md" }));
      });

      test("passes when viewport is within range", function (assert) {
        assert.true(this.condition.evaluate({ min: "sm", max: "lg" }));
      });

      test("fails when viewport is below range", function (assert) {
        this.condition.capabilities.viewport.sm = false;
        this.condition.capabilities.viewport.md = false;
        assert.false(this.condition.evaluate({ min: "md", max: "xl" }));
      });

      test("fails when viewport is above range", function (assert) {
        this.condition.capabilities.viewport.lg = true;
        this.condition.capabilities.viewport.xl = true;
        assert.false(this.condition.evaluate({ min: "sm", max: "md" }));
      });
    });

    module("touch device condition", function () {
      test("passes when touch: true and device has touch", function (assert) {
        this.condition.capabilities.touch = true;
        assert.true(this.condition.evaluate({ touch: true }));
      });

      test("fails when touch: true and device has no touch", function (assert) {
        assert.false(this.condition.evaluate({ touch: true }));
      });

      test("passes when touch: false and device has no touch", function (assert) {
        assert.true(this.condition.evaluate({ touch: false }));
      });

      test("fails when touch: false and device has touch", function (assert) {
        this.condition.capabilities.touch = true;
        assert.false(this.condition.evaluate({ touch: false }));
      });
    });

    module("combined conditions", function () {
      test("passes when all conditions are met", function (assert) {
        this.condition.capabilities.touch = true;
        assert.true(
          this.condition.evaluate({
            min: "sm",
            max: "lg",
            touch: true,
          })
        );
      });

      test("fails when breakpoint condition is not met", function (assert) {
        this.condition.capabilities.touch = true;
        assert.false(
          this.condition.evaluate({
            min: "lg",
            touch: true,
          })
        );
      });

      test("fails when touch condition is not met", function (assert) {
        assert.false(
          this.condition.evaluate({
            min: "sm",
            touch: true,
          })
        );
      });
    });
  });

  module("validate (constraints)", function () {
    test("returns error when no args specified (atLeastOne constraint)", function (assert) {
      const error = this.validateCondition({});
      assert.notStrictEqual(error, null, "returns an error");
      assert.true(
        error.message.includes("at least one of"),
        "error message mentions atLeastOne"
      );
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockViewportCondition.type, "viewport");
    });
  });
});
