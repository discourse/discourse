import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { BlockConditionValidationError } from "discourse/blocks/conditions";
import BlockRouteCondition, {
  BlockRouteConditionShortcuts,
} from "discourse/blocks/conditions/route";

module("Unit | Blocks | Condition | route", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockRouteCondition();
    setOwner(this.condition, getOwner(this));
  });

  module("validate", function () {
    test("throws when both routes and excludeRoutes are provided", function (assert) {
      assert.throws(
        () =>
          this.condition.validate({
            routes: ["discovery.latest"],
            excludeRoutes: ["discovery.top"],
          }),
        BlockConditionValidationError
      );
    });

    test("throws when neither routes nor excludeRoutes provided", function (assert) {
      assert.throws(
        () => this.condition.validate({}),
        BlockConditionValidationError
      );
    });

    test("passes with valid routes", function (assert) {
      this.condition.validate({ routes: ["discovery.latest"] });
      this.condition.validate({ excludeRoutes: ["discovery.top"] });
      this.condition.validate({ routes: [/^topic\.\d+$/] });
      this.condition.validate({
        routes: [BlockRouteConditionShortcuts.DISCOVERY],
      });
      assert.true(true, "all valid configurations passed");
    });
  });

  module("BlockRouteConditionShortcuts", function () {
    test("exports expected shortcuts", function (assert) {
      assert.true(
        !!BlockRouteConditionShortcuts.DISCOVERY,
        "DISCOVERY is defined"
      );
      assert.true(
        !!BlockRouteConditionShortcuts.HOMEPAGE,
        "HOMEPAGE is defined"
      );
      assert.true(
        !!BlockRouteConditionShortcuts.CATEGORY,
        "CATEGORY is defined"
      );
      assert.true(
        !!BlockRouteConditionShortcuts.TOP_MENU,
        "TOP_MENU is defined"
      );
      assert.strictEqual(
        typeof BlockRouteConditionShortcuts.DISCOVERY,
        "symbol"
      );
    });

    test("shortcuts are frozen", function (assert) {
      assert.true(Object.isFrozen(BlockRouteConditionShortcuts));
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockRouteCondition.type, "route");
    });
  });
});
