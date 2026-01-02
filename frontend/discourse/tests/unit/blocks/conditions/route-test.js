import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockRouteCondition, {
  BlockRouteConditionShortcuts,
} from "discourse/blocks/conditions/route";

module("Unit | Blocks | Conditions | route", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const testOwner = getOwner(this);

    // Default mock router state
    this.mockRouterState = {
      currentRouteName: "discovery.latest",
      currentRoute: {
        params: {},
        queryParams: {},
      },
    };

    // Mock discovery state
    this.mockDiscoveryState = {
      category: null,
      tag: null,
      custom: false,
      onDiscoveryRoute: true,
    };

    // Create mock router service
    const mockRouterState = this.mockRouterState;
    class MockRouter extends Service {
      get currentRouteName() {
        return mockRouterState.currentRouteName;
      }

      get currentRoute() {
        return mockRouterState.currentRoute;
      }
    }
    testOwner.unregister("service:router");
    testOwner.register("service:router", MockRouter);

    // Create mock discovery service
    const mockDiscoveryState = this.mockDiscoveryState;
    class MockDiscovery extends Service {
      get category() {
        return mockDiscoveryState.category;
      }

      get tag() {
        return mockDiscoveryState.tag;
      }

      get custom() {
        return mockDiscoveryState.custom;
      }

      get onDiscoveryRoute() {
        return mockDiscoveryState.onDiscoveryRoute;
      }
    }
    testOwner.unregister("service:discovery");
    testOwner.register("service:discovery", MockDiscovery);

    // Helper to evaluate route condition directly
    this.evaluateCondition = (args) => {
      const condition = new BlockRouteCondition();
      setOwner(condition, testOwner);
      return condition.evaluate(args);
    };

    // Helper to validate route condition
    this.validateCondition = (args) => {
      const condition = new BlockRouteCondition();
      setOwner(condition, testOwner);
      return condition.validate(args);
    };
  });

  module("params matching", function () {
    test("matches single param exact value", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123 },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 456 },
        })
      );
    });

    test("matches multiple params (AND logic)", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = {
        id: 123,
        slug: "my-topic",
      };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123, slug: "my-topic" },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123, slug: "other-topic" },
        })
      );
    });

    test("returns false when expected param is missing", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123, slug: "my-topic" },
        })
      );
    });

    test("matches param with array of values (OR)", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: [123, 456, 789] },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: [456, 789] },
        })
      );
    });

    test("matches param with regex", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { slug: "help-topic-123" };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { slug: /^help-/ },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { slug: /^support-/ },
        })
      );
    });

    test("matches param with NOT logic", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: { not: 456 } },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: { not: 123 } },
        })
      );
    });

    test("matches params with { any: [...] } OR logic", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123, slug: "my-topic" };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { any: [{ id: 456 }, { slug: "my-topic" }] },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { any: [{ id: 456 }, { slug: "other-topic" }] },
        })
      );
    });

    test("matches params with array (AND logic across specs)", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = {
        id: 123,
        slug: "help-topic",
      };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: [{ id: 123 }, { slug: /^help-/ }],
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: [{ id: 123 }, { slug: /^support-/ }],
        })
      );
    });

    test("matches params with { not: {...} } NOT logic", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { not: { id: 456 } },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { not: { id: 123 } },
        })
      );
    });

    test("nested logic: OR containing NOT", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = {
        id: 123,
        status: "open",
      };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { any: [{ id: 456 }, { status: { not: "closed" } }] },
        })
      );
    });
  });

  module("queryParams matching", function () {
    test("matches single queryParam exact value", function (assert) {
      this.mockRouterState.currentRouteName = "discovery.latest";
      this.mockRouterState.currentRoute.queryParams = { filter: "solved" };

      assert.true(
        this.evaluateCondition({
          routes: ["discovery.latest"],
          queryParams: { filter: "solved" },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["discovery.latest"],
          queryParams: { filter: "unsolved" },
        })
      );
    });

    test("matches queryParam with array of values (OR)", function (assert) {
      this.mockRouterState.currentRouteName = "discovery.latest";
      this.mockRouterState.currentRoute.queryParams = { filter: "solved" };

      assert.true(
        this.evaluateCondition({
          routes: ["discovery.latest"],
          queryParams: { filter: ["solved", "closed"] },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["discovery.latest"],
          queryParams: { filter: ["open", "closed"] },
        })
      );
    });

    test("matches queryParam with regex", function (assert) {
      this.mockRouterState.currentRouteName = "discovery.latest";
      this.mockRouterState.currentRoute.queryParams = { q: "javascript help" };

      assert.true(
        this.evaluateCondition({
          routes: ["discovery.latest"],
          queryParams: { q: /javascript/ },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["discovery.latest"],
          queryParams: { q: /python/ },
        })
      );
    });

    test("matches queryParams with { any: [...] } OR logic", function (assert) {
      this.mockRouterState.currentRouteName = "discovery.latest";
      this.mockRouterState.currentRoute.queryParams = {
        filter: "solved",
        page: "2",
      };

      assert.true(
        this.evaluateCondition({
          routes: ["discovery.latest"],
          queryParams: { any: [{ filter: "closed" }, { page: "2" }] },
        })
      );
    });
  });

  module("combined params and queryParams", function () {
    test("matches when both params and queryParams match", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123 };
      this.mockRouterState.currentRoute.queryParams = { page: "2" };

      assert.true(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123 },
          queryParams: { page: "2" },
        })
      );
    });

    test("returns false when params match but queryParams do not", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 123 };
      this.mockRouterState.currentRoute.queryParams = { page: "1" };

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123 },
          queryParams: { page: "2" },
        })
      );
    });

    test("returns false when queryParams match but params do not", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 456 };
      this.mockRouterState.currentRoute.queryParams = { page: "2" };

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123 },
          queryParams: { page: "2" },
        })
      );
    });

    test("returns false when route matches but params do not", function (assert) {
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = { id: 456 };

      assert.false(
        this.evaluateCondition({
          routes: ["topic.show"],
          params: { id: 123 },
        })
      );
    });
  });

  module("backslash escape for reserved keys", function () {
    test("\\\\any matches literal param named 'any'", function (assert) {
      this.mockRouterState.currentRouteName = "some.route";
      this.mockRouterState.currentRoute.params = { any: "some-value" };

      assert.true(
        this.evaluateCondition({
          routes: ["some.route"],
          params: { "\\any": "some-value" },
        })
      );

      assert.false(
        this.evaluateCondition({
          routes: ["some.route"],
          params: { "\\any": "other-value" },
        })
      );
    });

    test("\\\\not matches literal param named 'not'", function (assert) {
      this.mockRouterState.currentRouteName = "some.route";
      this.mockRouterState.currentRoute.params = { not: "some-value" };

      assert.true(
        this.evaluateCondition({
          routes: ["some.route"],
          params: { "\\not": "some-value" },
        })
      );
    });
  });

  module("route matching (existing behavior)", function () {
    test("matches exact route name", function (assert) {
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.true(this.evaluateCondition({ routes: ["discovery.latest"] }));

      assert.false(this.evaluateCondition({ routes: ["discovery.top"] }));
    });

    test("matches wildcard route pattern", function (assert) {
      this.mockRouterState.currentRouteName = "category.none";

      assert.true(this.evaluateCondition({ routes: ["category.*"] }));
    });

    test("excludeRoutes excludes specified routes", function (assert) {
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.true(
        this.evaluateCondition({
          excludeRoutes: ["discovery.custom"],
        })
      );

      assert.false(
        this.evaluateCondition({
          excludeRoutes: ["discovery.latest"],
        })
      );
    });
  });

  module("validate", function () {
    test("throws when both routes and excludeRoutes are provided", function (assert) {
      assert.throws(
        () =>
          this.validateCondition({
            routes: ["discovery.latest"],
            excludeRoutes: ["topic.show"],
          }),
        /Cannot use both/
      );
    });

    test("throws when neither routes nor excludeRoutes are provided", function (assert) {
      assert.throws(() => this.validateCondition({}), /Must provide either/);
    });

    test("throws for unknown symbol shortcuts", function (assert) {
      assert.throws(
        () => this.validateCondition({ routes: [Symbol("UNKNOWN")] }),
        /Unknown route shortcut/
      );
    });

    test("accepts valid symbol shortcuts", function (assert) {
      this.validateCondition({
        routes: [BlockRouteConditionShortcuts.CATEGORY_PAGES],
      });
      assert.true(true);
    });

    test("accepts valid symbol shortcuts in excludeRoutes", function (assert) {
      this.validateCondition({
        excludeRoutes: [BlockRouteConditionShortcuts.HOMEPAGE],
      });
      assert.true(true);
    });
  });

  module("shortcuts", function () {
    test("CATEGORY_PAGES matches when discovery.category is set", function (assert) {
      this.mockDiscoveryState.category = { id: 1, name: "test" };
      this.mockRouterState.currentRouteName = "discovery.category";

      assert.true(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.CATEGORY_PAGES],
        })
      );
    });

    test("CATEGORY_PAGES does not match when category is null", function (assert) {
      this.mockDiscoveryState.category = null;
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.CATEGORY_PAGES],
        })
      );
    });

    test("DISCOVERY_PAGES matches on discovery routes excluding custom", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.true(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.DISCOVERY_PAGES],
        })
      );
    });

    test("DISCOVERY_PAGES does not match on custom homepage", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentRouteName = "discovery.custom";

      assert.false(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.DISCOVERY_PAGES],
        })
      );
    });

    test("HOMEPAGE matches only on custom homepage", function (assert) {
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentRouteName = "discovery.custom";

      assert.true(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.HOMEPAGE],
        })
      );
    });

    test("HOMEPAGE does not match on regular discovery routes", function (assert) {
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.HOMEPAGE],
        })
      );
    });

    test("TAG_PAGES matches when discovery.tag is set", function (assert) {
      this.mockDiscoveryState.tag = { id: 1, name: "javascript" };
      this.mockRouterState.currentRouteName = "tag.show";

      assert.true(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.TAG_PAGES],
        })
      );
    });

    test("TAG_PAGES does not match when tag is null", function (assert) {
      this.mockDiscoveryState.tag = null;
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.TAG_PAGES],
        })
      );
    });

    test("TOP_MENU matches on main navigation discovery routes", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.true(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.TOP_MENU],
        })
      );
    });

    test("TOP_MENU does not match on category pages", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = { id: 1, name: "test" };
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentRouteName = "discovery.category";

      assert.false(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.TOP_MENU],
        })
      );
    });

    test("TOP_MENU does not match on tag pages", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = { id: 1, name: "javascript" };
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentRouteName = "tag.show";

      assert.false(
        this.evaluateCondition({
          routes: [BlockRouteConditionShortcuts.TOP_MENU],
        })
      );
    });
  });
});
