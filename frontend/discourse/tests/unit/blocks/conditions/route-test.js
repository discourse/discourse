import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockRouteCondition from "discourse/blocks/conditions/route";
import { setPrefix } from "discourse/lib/get-url";

module("Unit | Blocks | Conditions | route", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const testOwner = getOwner(this);

    // Reset URL prefix for clean tests
    setPrefix("");

    // Default mock router state
    this.mockRouterState = {
      currentURL: "/latest",
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
      get currentURL() {
        return mockRouterState.currentURL;
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

  module("URL pattern matching", function () {
    test("matches exact URL path", function (assert) {
      this.mockRouterState.currentURL = "/latest";

      assert.true(this.evaluateCondition({ urls: ["/latest"] }));
      assert.false(this.evaluateCondition({ urls: ["/top"] }));
    });

    test("matches single wildcard (*)", function (assert) {
      this.mockRouterState.currentURL = "/c/general";

      assert.true(this.evaluateCondition({ urls: ["/c/*"] }));
    });

    test("single wildcard does not match multiple segments", function (assert) {
      this.mockRouterState.currentURL = "/c/general/subcategory";

      assert.false(this.evaluateCondition({ urls: ["/c/*"] }));
    });

    test("matches double wildcard (**)", function (assert) {
      this.mockRouterState.currentURL = "/c/general/subcategory";

      assert.true(this.evaluateCondition({ urls: ["/c/**"] }));
    });

    test("double wildcard matches zero segments", function (assert) {
      this.mockRouterState.currentURL = "/c";

      assert.true(this.evaluateCondition({ urls: ["/c/**"] }));
    });

    test("matches multiple patterns (OR logic)", function (assert) {
      this.mockRouterState.currentURL = "/c/general";

      assert.true(this.evaluateCondition({ urls: ["/c/**", "/tag/*"] }));
    });

    test("does not match when no patterns match", function (assert) {
      this.mockRouterState.currentURL = "/latest";

      assert.false(this.evaluateCondition({ urls: ["/c/**", "/tag/*"] }));
    });

    test("matches wildcard in middle of pattern", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";

      assert.true(this.evaluateCondition({ urls: ["/t/*/123"] }));
      assert.false(this.evaluateCondition({ urls: ["/t/*/456"] }));
    });

    test("matches brace expansion", function (assert) {
      this.mockRouterState.currentURL = "/latest";

      assert.true(this.evaluateCondition({ urls: ["/{latest,top,new}"] }));

      this.mockRouterState.currentURL = "/top";
      assert.true(this.evaluateCondition({ urls: ["/{latest,top,new}"] }));

      this.mockRouterState.currentURL = "/unread";
      assert.false(this.evaluateCondition({ urls: ["/{latest,top,new}"] }));
    });

    test("matches character class", function (assert) {
      this.mockRouterState.currentURL = "/api/v1";

      assert.true(this.evaluateCondition({ urls: ["/api/v[123]"] }));

      this.mockRouterState.currentURL = "/api/v4";
      assert.false(this.evaluateCondition({ urls: ["/api/v[123]"] }));
    });
  });

  module("subfolder support", function () {
    test("strips subfolder prefix before matching", function (assert) {
      setPrefix("/forum");
      this.mockRouterState.currentURL = "/forum/c/general";

      assert.true(this.evaluateCondition({ urls: ["/c/**"] }));
    });

    test("matches root path with subfolder", function (assert) {
      setPrefix("/discourse");
      this.mockRouterState.currentURL = "/discourse/";

      // Root path after normalization
      assert.true(this.evaluateCondition({ urls: ["/"] }));
    });

    test("handles complex subfolder with query params", function (assert) {
      setPrefix("/forum");
      this.mockRouterState.currentURL = "/forum/c/general?filter=latest";

      assert.true(this.evaluateCondition({ urls: ["/c/**"] }));
    });
  });

  module("excludeUrls", function () {
    test("passes when URL does not match exclude pattern", function (assert) {
      this.mockRouterState.currentURL = "/c/general";

      assert.true(this.evaluateCondition({ excludeUrls: ["/admin/**"] }));
    });

    test("fails when URL matches exclude pattern", function (assert) {
      this.mockRouterState.currentURL = "/admin/dashboard";

      assert.false(this.evaluateCondition({ excludeUrls: ["/admin/**"] }));
    });

    test("excludeUrls alone allows all except specified", function (assert) {
      this.mockRouterState.currentURL = "/latest";
      assert.true(this.evaluateCondition({ excludeUrls: ["/admin/**"] }));

      this.mockRouterState.currentURL = "/c/general";
      assert.true(this.evaluateCondition({ excludeUrls: ["/admin/**"] }));

      this.mockRouterState.currentURL = "/t/topic/123";
      assert.true(this.evaluateCondition({ excludeUrls: ["/admin/**"] }));
    });

    test("multiple exclude patterns (all must not match)", function (assert) {
      this.mockRouterState.currentURL = "/latest";

      assert.true(
        this.evaluateCondition({ excludeUrls: ["/admin/**", "/wizard/**"] })
      );

      this.mockRouterState.currentURL = "/admin/plugins";
      assert.false(
        this.evaluateCondition({ excludeUrls: ["/admin/**", "/wizard/**"] })
      );

      this.mockRouterState.currentURL = "/wizard/step1";
      assert.false(
        this.evaluateCondition({ excludeUrls: ["/admin/**", "/wizard/**"] })
      );
    });
  });

  module("shortcuts ($SHORTCUT_NAME)", function () {
    test("$CATEGORY_PAGES matches when discovery.category is set", function (assert) {
      this.mockDiscoveryState.category = { id: 1, name: "test" };
      this.mockRouterState.currentURL = "/c/test";

      assert.true(this.evaluateCondition({ urls: ["$CATEGORY_PAGES"] }));
    });

    test("$CATEGORY_PAGES does not match when category is null", function (assert) {
      this.mockDiscoveryState.category = null;
      this.mockRouterState.currentURL = "/latest";

      assert.false(this.evaluateCondition({ urls: ["$CATEGORY_PAGES"] }));
    });

    test("$DISCOVERY_PAGES matches on discovery routes excluding custom", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";

      assert.true(this.evaluateCondition({ urls: ["$DISCOVERY_PAGES"] }));
    });

    test("$DISCOVERY_PAGES does not match on custom homepage", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentURL = "/";

      assert.false(this.evaluateCondition({ urls: ["$DISCOVERY_PAGES"] }));
    });

    test("$HOMEPAGE matches only on custom homepage", function (assert) {
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentURL = "/";

      assert.true(this.evaluateCondition({ urls: ["$HOMEPAGE"] }));
    });

    test("$HOMEPAGE does not match on regular discovery routes", function (assert) {
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";

      assert.false(this.evaluateCondition({ urls: ["$HOMEPAGE"] }));
    });

    test("$TAG_PAGES matches when discovery.tag is set", function (assert) {
      this.mockDiscoveryState.tag = { id: 1, name: "javascript" };
      this.mockRouterState.currentURL = "/tag/javascript";

      assert.true(this.evaluateCondition({ urls: ["$TAG_PAGES"] }));
    });

    test("$TAG_PAGES does not match when tag is null", function (assert) {
      this.mockDiscoveryState.tag = null;
      this.mockRouterState.currentURL = "/latest";

      assert.false(this.evaluateCondition({ urls: ["$TAG_PAGES"] }));
    });

    test("$TOP_MENU matches on main navigation discovery routes", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";

      assert.true(this.evaluateCondition({ urls: ["$TOP_MENU"] }));
    });

    test("$TOP_MENU does not match on category pages", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = { id: 1, name: "test" };
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/c/test";

      assert.false(this.evaluateCondition({ urls: ["$TOP_MENU"] }));
    });

    test("$TOP_MENU does not match on tag pages", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = { id: 1, name: "javascript" };
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/tag/javascript";

      assert.false(this.evaluateCondition({ urls: ["$TOP_MENU"] }));
    });

    test("shortcuts work in excludeUrls", function (assert) {
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentURL = "/";

      assert.false(this.evaluateCondition({ excludeUrls: ["$HOMEPAGE"] }));

      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";

      assert.true(this.evaluateCondition({ excludeUrls: ["$HOMEPAGE"] }));
    });
  });

  module("mixed patterns and shortcuts", function () {
    test("matches when URL pattern matches (shortcut doesn't)", function (assert) {
      this.mockDiscoveryState.category = null;
      this.mockRouterState.currentURL = "/c/general";

      // $CATEGORY_PAGES won't match (category is null), but /c/** will
      assert.true(
        this.evaluateCondition({ urls: ["$CATEGORY_PAGES", "/c/**"] })
      );
    });

    test("matches when shortcut matches (URL pattern doesn't)", function (assert) {
      this.mockDiscoveryState.category = { id: 1, name: "test" };
      this.mockRouterState.currentURL = "/c/test";

      // /admin/** won't match, but $CATEGORY_PAGES will
      assert.true(
        this.evaluateCondition({ urls: ["/admin/**", "$CATEGORY_PAGES"] })
      );
    });

    test("fails when neither pattern nor shortcut matches", function (assert) {
      this.mockDiscoveryState.category = null;
      this.mockRouterState.currentURL = "/latest";

      assert.false(
        this.evaluateCondition({ urls: ["$CATEGORY_PAGES", "/c/**"] })
      );
    });
  });

  module("params matching", function () {
    test("matches single param exact value", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.true(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: 123 },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: 456 },
        })
      );
    });

    test("matches multiple params (AND logic)", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRoute.params = {
        id: 123,
        slug: "my-topic",
      };

      assert.true(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: 123, slug: "my-topic" },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: 123, slug: "other-topic" },
        })
      );
    });

    test("matches param with array of values (OR)", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.true(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: [123, 456, 789] },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: [456, 789] },
        })
      );
    });

    test("matches param with regex", function (assert) {
      this.mockRouterState.currentURL = "/t/help-topic-123/1";
      this.mockRouterState.currentRoute.params = { slug: "help-topic-123" };

      assert.true(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { slug: /^help-/ },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { slug: /^support-/ },
        })
      );
    });

    test("matches param with NOT logic", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRoute.params = { id: 123 };

      assert.true(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: { not: 456 } },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: { not: 123 } },
        })
      );
    });

    test("matches params with { any: [...] } OR logic", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRoute.params = { id: 123, slug: "my-topic" };

      assert.true(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { any: [{ id: 456 }, { slug: "my-topic" }] },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { any: [{ id: 456 }, { slug: "other-topic" }] },
        })
      );
    });
  });

  module("queryParams matching", function () {
    test("matches single queryParam exact value", function (assert) {
      this.mockRouterState.currentURL = "/latest?filter=solved";
      this.mockRouterState.currentRoute.queryParams = { filter: "solved" };

      assert.true(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { filter: "solved" },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { filter: "unsolved" },
        })
      );
    });

    test("matches queryParam with array of values (OR)", function (assert) {
      this.mockRouterState.currentURL = "/latest?filter=solved";
      this.mockRouterState.currentRoute.queryParams = { filter: "solved" };

      assert.true(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { filter: ["solved", "closed"] },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { filter: ["open", "closed"] },
        })
      );
    });

    test("matches queryParam with regex", function (assert) {
      this.mockRouterState.currentURL = "/latest?q=javascript%20help";
      this.mockRouterState.currentRoute.queryParams = { q: "javascript help" };

      assert.true(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { q: /javascript/ },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { q: /python/ },
        })
      );
    });

    test("matches queryParams with { any: [...] } OR logic", function (assert) {
      this.mockRouterState.currentURL = "/latest?filter=solved&page=2";
      this.mockRouterState.currentRoute.queryParams = {
        filter: "solved",
        page: "2",
      };

      assert.true(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { any: [{ filter: "closed" }, { page: "2" }] },
        })
      );
    });
  });

  module("combined params and queryParams", function () {
    test("matches when both params and queryParams match", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123?page=2";
      this.mockRouterState.currentRoute.params = { id: 123 };
      this.mockRouterState.currentRoute.queryParams = { page: "2" };

      assert.true(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: 123 },
          queryParams: { page: "2" },
        })
      );
    });

    test("returns false when params match but queryParams do not", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123?page=1";
      this.mockRouterState.currentRoute.params = { id: 123 };
      this.mockRouterState.currentRoute.queryParams = { page: "1" };

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: 123 },
          queryParams: { page: "2" },
        })
      );
    });

    test("returns false when URL matches but params do not", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/456";
      this.mockRouterState.currentRoute.params = { id: 456 };

      assert.false(
        this.evaluateCondition({
          urls: ["/t/**"],
          params: { id: 123 },
        })
      );
    });
  });

  module("shortcuts with queryParams", function () {
    test("shortcut + queryParams both must match", function (assert) {
      this.mockDiscoveryState.category = { id: 1, name: "test" };
      this.mockRouterState.currentURL = "/c/test?filter=latest";
      this.mockRouterState.currentRoute.queryParams = { filter: "latest" };

      assert.true(
        this.evaluateCondition({
          urls: ["$CATEGORY_PAGES"],
          queryParams: { filter: "latest" },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["$CATEGORY_PAGES"],
          queryParams: { filter: "top" },
        })
      );
    });
  });

  module("validate", function () {
    test("throws when neither urls nor excludeUrls provided", function (assert) {
      assert.throws(
        () => this.validateCondition({}),
        /Must provide `urls` or `excludeUrls`/
      );
    });

    test("throws when both urls and excludeUrls provided", function (assert) {
      assert.throws(
        () =>
          this.validateCondition({
            urls: ["/latest"],
            excludeUrls: ["/admin/**"],
          }),
        /Cannot use both/
      );
    });

    test("throws for unknown shortcut", function (assert) {
      assert.throws(
        () => this.validateCondition({ urls: ["$INVALID_SHORTCUT"] }),
        /unknown shortcut "\$INVALID_SHORTCUT"/
      );
    });

    test("throws for unknown shortcut in excludeUrls", function (assert) {
      assert.throws(
        () => this.validateCondition({ excludeUrls: ["$UNKNOWN"] }),
        /unknown shortcut "\$UNKNOWN"/
      );
    });

    test("accepts valid shortcuts", function (assert) {
      this.validateCondition({ urls: ["$CATEGORY_PAGES"] });
      this.validateCondition({ urls: ["$DISCOVERY_PAGES"] });
      this.validateCondition({ urls: ["$HOMEPAGE"] });
      this.validateCondition({ urls: ["$TAG_PAGES"] });
      this.validateCondition({ urls: ["$TOP_MENU"] });
      assert.true(true);
    });

    test("accepts valid URL patterns", function (assert) {
      this.validateCondition({ urls: ["/c/**"] });
      this.validateCondition({ urls: ["/t/*"] });
      this.validateCondition({ excludeUrls: ["/admin/**"] });
      assert.true(true);
    });

    test("accepts mixed patterns and shortcuts", function (assert) {
      this.validateCondition({
        urls: ["$CATEGORY_PAGES", "/c/**", "/custom/*"],
      });
      assert.true(true);
    });

    test("throws for invalid glob pattern in urls", function (assert) {
      assert.throws(
        () => this.validateCondition({ urls: ["[unclosed"] }),
        /Invalid glob pattern "\[unclosed"/
      );
    });

    test("throws for invalid glob pattern in excludeUrls", function (assert) {
      assert.throws(
        () => this.validateCondition({ excludeUrls: ["{unclosed"] }),
        /Invalid glob pattern "\{unclosed"/
      );
    });
  });

  module("backslash escape for reserved keys", function () {
    test("\\\\any matches literal param named 'any'", function (assert) {
      this.mockRouterState.currentURL = "/some/route";
      this.mockRouterState.currentRoute.params = { any: "some-value" };

      assert.true(
        this.evaluateCondition({
          urls: ["/some/**"],
          params: { "\\any": "some-value" },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/some/**"],
          params: { "\\any": "other-value" },
        })
      );
    });

    test("\\\\not matches literal param named 'not'", function (assert) {
      this.mockRouterState.currentURL = "/some/route";
      this.mockRouterState.currentRoute.params = { not: "some-value" };

      assert.true(
        this.evaluateCondition({
          urls: ["/some/**"],
          params: { "\\not": "some-value" },
        })
      );
    });
  });
});
