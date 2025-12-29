import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { BlockConditionValidationError } from "discourse/blocks/conditions";
import BlockViewportCondition from "discourse/blocks/conditions/viewport";

module("Unit | Blocks | Condition | viewport", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockViewportCondition();
    setOwner(this.condition, getOwner(this));
  });

  module("validate", function () {
    test("throws for invalid min breakpoint", function (assert) {
      assert.throws(
        () => this.condition.validate({ min: "xxl" }),
        BlockConditionValidationError
      );
    });

    test("throws for invalid max breakpoint", function (assert) {
      assert.throws(
        () => this.condition.validate({ max: "invalid" }),
        BlockConditionValidationError
      );
    });

    test("throws when min > max", function (assert) {
      assert.throws(
        () => this.condition.validate({ min: "xl", max: "sm" }),
        BlockConditionValidationError
      );
    });

    test("passes valid breakpoint configurations", function (assert) {
      this.condition.validate({ min: "sm" });
      this.condition.validate({ max: "lg" });
      this.condition.validate({ min: "md", max: "xl" });
      this.condition.validate({ min: "2xl" });
      this.condition.validate({ mobile: true });
      this.condition.validate({ touch: true });
      this.condition.validate({ mobile: false, touch: false });
      assert.true(true, "all valid configurations passed");
    });

    test("passes when min equals max", function (assert) {
      this.condition.validate({ min: "md", max: "md" });
      assert.true(true, "min equals max is valid");
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockViewportCondition.type, "viewport");
    });
  });
});
