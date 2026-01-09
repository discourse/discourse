import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockViewportCondition from "discourse/blocks/conditions/viewport";

module("Unit | Blocks | Condition | viewport", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockViewportCondition();
    setOwner(this.condition, getOwner(this));

    // Helper that throws if validation returns an error (for assert.throws tests)
    this.validateOrThrow = (args) => {
      const error = this.condition.validate(args);
      if (error) {
        throw new Error(error.message);
      }
    };
  });

  module("validate", function () {
    test("throws for invalid min breakpoint", function (assert) {
      assert.throws(
        () => this.validateOrThrow({ min: "xxl" }),
        /Invalid.*breakpoint/
      );
    });

    test("throws for invalid max breakpoint", function (assert) {
      assert.throws(
        () => this.validateOrThrow({ max: "invalid" }),
        /Invalid.*breakpoint/
      );
    });

    test("throws when min > max", function (assert) {
      assert.throws(
        () => this.validateOrThrow({ min: "xl", max: "sm" }),
        /min.*breakpoint.*larger than.*max/
      );
    });

    test("passes valid breakpoint configurations", function (assert) {
      assert.strictEqual(this.condition.validate({ min: "sm" }), null);
      assert.strictEqual(this.condition.validate({ max: "lg" }), null);
      assert.strictEqual(
        this.condition.validate({ min: "md", max: "xl" }),
        null
      );
      assert.strictEqual(this.condition.validate({ min: "2xl" }), null);
      assert.strictEqual(this.condition.validate({ mobile: true }), null);
      assert.strictEqual(this.condition.validate({ touch: true }), null);
      assert.strictEqual(
        this.condition.validate({ mobile: false, touch: false }),
        null
      );
    });

    test("passes when min equals max", function (assert) {
      assert.strictEqual(
        this.condition.validate({ min: "md", max: "md" }),
        null
      );
    });
  });

  module("evaluate", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.condition.capabilities = {
        isMobileDevice: false,
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

    module("mobile device condition", function () {
      test("passes when mobile: true and device is mobile", function (assert) {
        this.condition.capabilities.isMobileDevice = true;
        assert.true(this.condition.evaluate({ mobile: true }));
      });

      test("fails when mobile: true and device is not mobile", function (assert) {
        assert.false(this.condition.evaluate({ mobile: true }));
      });

      test("passes when mobile: false and device is not mobile", function (assert) {
        assert.true(this.condition.evaluate({ mobile: false }));
      });

      test("fails when mobile: false and device is mobile", function (assert) {
        this.condition.capabilities.isMobileDevice = true;
        assert.false(this.condition.evaluate({ mobile: false }));
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
        this.condition.capabilities.isMobileDevice = true;
        this.condition.capabilities.touch = true;
        assert.true(
          this.condition.evaluate({
            min: "sm",
            max: "lg",
            mobile: true,
            touch: true,
          })
        );
      });

      test("fails when breakpoint condition is not met", function (assert) {
        this.condition.capabilities.isMobileDevice = true;
        this.condition.capabilities.touch = true;
        assert.false(
          this.condition.evaluate({
            min: "lg",
            mobile: true,
            touch: true,
          })
        );
      });

      test("fails when mobile condition is not met", function (assert) {
        assert.false(
          this.condition.evaluate({
            min: "sm",
            mobile: true,
          })
        );
      });
    });

    test("passes with no conditions", function (assert) {
      assert.true(this.condition.evaluate({}));
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockViewportCondition.type, "viewport");
    });
  });
});
