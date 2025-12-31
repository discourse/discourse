import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
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
        !!BlockRouteConditionShortcuts.DISCOVERY_PAGES,
        "DISCOVERY_PAGES is defined"
      );
      assert.true(
        !!BlockRouteConditionShortcuts.HOMEPAGE,
        "HOMEPAGE is defined"
      );
      assert.true(
        !!BlockRouteConditionShortcuts.CATEGORY_PAGES,
        "CATEGORY_PAGES is defined"
      );
      assert.true(
        !!BlockRouteConditionShortcuts.TAG_PAGES,
        "TAG_PAGES is defined"
      );
      assert.true(
        !!BlockRouteConditionShortcuts.TOP_MENU,
        "TOP_MENU is defined"
      );
      assert.strictEqual(
        typeof BlockRouteConditionShortcuts.DISCOVERY_PAGES,
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

  module("evaluate with shortcuts", function () {
    test("CATEGORY_PAGES matches when discovery.category is truthy", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.category";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = { id: 1, name: "General" };
          tag = null;
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.CATEGORY_PAGES],
      });
      assert.true(result, "matches category page");
    });

    test("CATEGORY_PAGES does not match when discovery.category is falsy", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.latest";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.CATEGORY_PAGES],
      });
      assert.false(result, "does not match non-category page");
    });

    test("DISCOVERY_PAGES matches discovery routes excluding custom homepage", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.latest";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.DISCOVERY_PAGES],
      });
      assert.true(result, "matches discovery page");
    });

    test("DISCOVERY_PAGES does not match custom homepage", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.custom";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = true;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.DISCOVERY_PAGES],
      });
      assert.false(result, "does not match custom homepage");
    });

    test("HOMEPAGE matches when discovery.custom is truthy", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.custom";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = true;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.HOMEPAGE],
      });
      assert.true(result, "matches custom homepage");
    });

    test("HOMEPAGE does not match regular discovery page", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.latest";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.HOMEPAGE],
      });
      assert.false(result, "does not match regular discovery page");
    });

    test("TAG_PAGES matches when discovery.tag is truthy", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "tags.show";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = { id: "javascript", name: "javascript" };
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.TAG_PAGES],
      });
      assert.true(result, "matches tag page");
    });

    test("TAG_PAGES does not match when discovery.tag is falsy", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.latest";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.TAG_PAGES],
      });
      assert.false(result, "does not match non-tag page");
    });

    test("TOP_MENU matches discovery routes excluding category, tag, and custom homepage", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.latest";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.TOP_MENU],
      });
      assert.true(result, "matches top menu route");
    });

    test("TOP_MENU does not match category page", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.category";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = { id: 1 };
          tag = null;
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.TOP_MENU],
      });
      assert.false(result, "does not match category page");
    });

    test("TOP_MENU does not match tag page", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "tags.show";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = { id: "test" };
          custom = false;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.TOP_MENU],
      });
      assert.false(result, "does not match tag page");
    });

    test("TOP_MENU does not match custom homepage", function (assert) {
      this.owner.unregister("service:router");
      this.owner.unregister("service:discovery");
      this.owner.register(
        "service:router",
        class extends Service {
          currentRouteName = "discovery.custom";
        }
      );
      this.owner.register(
        "service:discovery",
        class extends Service {
          category = null;
          tag = null;
          custom = true;
          onDiscoveryRoute = true;
        }
      );
      const condition = new BlockRouteCondition();
      setOwner(condition, getOwner(this));

      const result = condition.evaluate({
        routes: [BlockRouteConditionShortcuts.TOP_MENU],
      });
      assert.false(result, "does not match custom homepage");
    });
  });
});
