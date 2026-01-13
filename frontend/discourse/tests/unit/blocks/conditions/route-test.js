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
      get currentURL() {
        return mockRouterState.currentURL;
      }

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

    // Helper to validate route condition (returns error or null)
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

      assert.true(this.evaluateCondition({ urls: ["/"] }));
    });

    test("handles complex subfolder with query params", function (assert) {
      setPrefix("/forum");
      this.mockRouterState.currentURL = "/forum/c/general?filter=latest";

      assert.true(this.evaluateCondition({ urls: ["/c/**"] }));
    });
  });

  module("pages: CATEGORY_PAGES", function () {
    test("matches when discovery.category is set", function (assert) {
      this.mockDiscoveryState.category = {
        id: 1,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general";

      assert.true(this.evaluateCondition({ pages: ["CATEGORY_PAGES"] }));
    });

    test("does not match when category is null", function (assert) {
      this.mockDiscoveryState.category = null;
      this.mockRouterState.currentURL = "/latest";

      assert.false(this.evaluateCondition({ pages: ["CATEGORY_PAGES"] }));
    });

    test("matches specific category by ID", function (assert) {
      this.mockDiscoveryState.category = {
        id: 5,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general";

      assert.true(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categoryId: 5 },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categoryId: 10 },
        })
      );
    });

    test("matches category by slug", function (assert) {
      this.mockDiscoveryState.category = {
        id: 1,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general";

      assert.true(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categorySlug: "general" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categorySlug: "support" },
        })
      );
    });

    test("matches subcategory by parentCategoryId", function (assert) {
      this.mockDiscoveryState.category = {
        id: 10,
        slug: "javascript",
        parent_category_id: 5,
      };
      this.mockRouterState.currentURL = "/c/programming/javascript";

      assert.true(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { parentCategoryId: 5 },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { parentCategoryId: 99 },
        })
      );
    });

    test("matches multiple params (AND logic)", function (assert) {
      this.mockDiscoveryState.category = {
        id: 5,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general";

      assert.true(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categoryId: 5, categorySlug: "general" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categoryId: 5, categorySlug: "other" },
        })
      );
    });
  });

  module("pages: TAG_PAGES", function () {
    test("matches when discovery.tag is set", function (assert) {
      this.mockDiscoveryState.tag = { name: "javascript" };
      this.mockRouterState.currentURL = "/tag/javascript";

      assert.true(this.evaluateCondition({ pages: ["TAG_PAGES"] }));
    });

    test("does not match when tag is null", function (assert) {
      this.mockDiscoveryState.tag = null;
      this.mockRouterState.currentURL = "/latest";

      assert.false(this.evaluateCondition({ pages: ["TAG_PAGES"] }));
    });

    test("matches specific tag by tagId", function (assert) {
      this.mockDiscoveryState.tag = { name: "javascript" };
      this.mockRouterState.currentURL = "/tag/javascript";

      assert.true(
        this.evaluateCondition({
          pages: ["TAG_PAGES"],
          params: { tagId: "javascript" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["TAG_PAGES"],
          params: { tagId: "python" },
        })
      );
    });

    test("matches tag filtered by category", function (assert) {
      this.mockDiscoveryState.tag = { name: "javascript" };
      this.mockDiscoveryState.category = {
        id: 5,
        slug: "programming",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/tags/c/programming/javascript";

      assert.true(
        this.evaluateCondition({
          pages: ["TAG_PAGES"],
          params: { tagId: "javascript", categoryId: 5 },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["TAG_PAGES"],
          params: { tagId: "javascript", categoryId: 10 },
        })
      );
    });
  });

  module("pages: DISCOVERY_PAGES", function () {
    test("matches on discovery routes excluding custom", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.true(this.evaluateCondition({ pages: ["DISCOVERY_PAGES"] }));
    });

    test("does not match on custom homepage", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentURL = "/";

      assert.false(this.evaluateCondition({ pages: ["DISCOVERY_PAGES"] }));
    });

    test("does not match when not on discovery route", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = false;
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRouteName = "topic.show";

      assert.false(this.evaluateCondition({ pages: ["DISCOVERY_PAGES"] }));
    });

    test("matches specific filter", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.true(
        this.evaluateCondition({
          pages: ["DISCOVERY_PAGES"],
          params: { filter: "latest" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["DISCOVERY_PAGES"],
          params: { filter: "top" },
        })
      );
    });
  });

  module("pages: HOMEPAGE", function () {
    test("matches only on custom homepage", function (assert) {
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentURL = "/";

      assert.true(this.evaluateCondition({ pages: ["HOMEPAGE"] }));
    });

    test("does not match on regular discovery routes", function (assert) {
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";

      assert.false(this.evaluateCondition({ pages: ["HOMEPAGE"] }));
    });
  });

  module("pages: TOP_MENU", function () {
    test("matches on main navigation discovery routes", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.true(this.evaluateCondition({ pages: ["TOP_MENU"] }));
    });

    test("does not match on category pages", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = { id: 1, slug: "test" };
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/c/test";

      assert.false(this.evaluateCondition({ pages: ["TOP_MENU"] }));
    });

    test("does not match on tag pages", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = { name: "javascript" };
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/tag/javascript";

      assert.false(this.evaluateCondition({ pages: ["TOP_MENU"] }));
    });

    test("does not match on custom homepage", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = true;
      this.mockRouterState.currentURL = "/";

      assert.false(this.evaluateCondition({ pages: ["TOP_MENU"] }));
    });

    test("matches specific filter", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = true;
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = null;
      this.mockDiscoveryState.custom = false;
      this.mockRouterState.currentURL = "/top";
      this.mockRouterState.currentRouteName = "discovery.top";

      assert.true(
        this.evaluateCondition({
          pages: ["TOP_MENU"],
          params: { filter: "top" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["TOP_MENU"],
          params: { filter: "latest" },
        })
      );
    });
  });

  module("pages: TOPIC_PAGES", function () {
    test("matches on topic routes", function (assert) {
      this.mockDiscoveryState.onDiscoveryRoute = false;
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = {
        id: "123",
        slug: "my-topic",
      };

      assert.true(this.evaluateCondition({ pages: ["TOPIC_PAGES"] }));
    });

    test("does not match on non-topic routes", function (assert) {
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(this.evaluateCondition({ pages: ["TOPIC_PAGES"] }));
    });

    test("matches specific topic by ID", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = {
        id: "123",
        slug: "my-topic",
      };

      assert.true(
        this.evaluateCondition({
          pages: ["TOPIC_PAGES"],
          params: { id: 123 },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["TOPIC_PAGES"],
          params: { id: 456 },
        })
      );
    });

    test("matches topic by slug", function (assert) {
      this.mockRouterState.currentURL = "/t/my-topic/123";
      this.mockRouterState.currentRouteName = "topic.show";
      this.mockRouterState.currentRoute.params = {
        id: "123",
        slug: "my-topic",
      };

      assert.true(
        this.evaluateCondition({
          pages: ["TOPIC_PAGES"],
          params: { slug: "my-topic" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["TOPIC_PAGES"],
          params: { slug: "other-topic" },
        })
      );
    });
  });

  module("pages: USER_PAGES", function () {
    test("matches on user profile routes", function (assert) {
      this.mockRouterState.currentURL = "/u/admin";
      this.mockRouterState.currentRouteName = "user.summary";
      this.mockRouterState.currentRoute.params = { username: "admin" };

      assert.true(this.evaluateCondition({ pages: ["USER_PAGES"] }));
    });

    test("does not match on non-user routes", function (assert) {
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(this.evaluateCondition({ pages: ["USER_PAGES"] }));
    });

    test("matches specific user by username", function (assert) {
      this.mockRouterState.currentURL = "/u/admin";
      this.mockRouterState.currentRouteName = "user.summary";
      this.mockRouterState.currentRoute.params = { username: "admin" };

      assert.true(
        this.evaluateCondition({
          pages: ["USER_PAGES"],
          params: { username: "admin" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["USER_PAGES"],
          params: { username: "other-user" },
        })
      );
    });
  });

  module("pages: ADMIN_PAGES", function () {
    test("matches on admin routes", function (assert) {
      this.mockRouterState.currentURL = "/admin/dashboard";
      this.mockRouterState.currentRouteName = "admin.dashboard";

      assert.true(this.evaluateCondition({ pages: ["ADMIN_PAGES"] }));
    });

    test("matches on nested admin routes", function (assert) {
      this.mockRouterState.currentURL = "/admin/plugins/discourse-ai";
      this.mockRouterState.currentRouteName = "admin.plugins.show";

      assert.true(this.evaluateCondition({ pages: ["ADMIN_PAGES"] }));
    });

    test("does not match on non-admin routes", function (assert) {
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(this.evaluateCondition({ pages: ["ADMIN_PAGES"] }));
    });
  });

  module("pages: GROUP_PAGES", function () {
    test("matches on group routes", function (assert) {
      this.mockRouterState.currentURL = "/g/staff";
      this.mockRouterState.currentRouteName = "group.index";
      this.mockRouterState.currentRoute.params = { name: "staff" };

      assert.true(this.evaluateCondition({ pages: ["GROUP_PAGES"] }));
    });

    test("does not match on non-group routes", function (assert) {
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(this.evaluateCondition({ pages: ["GROUP_PAGES"] }));
    });

    test("matches specific group by name", function (assert) {
      this.mockRouterState.currentURL = "/g/staff";
      this.mockRouterState.currentRouteName = "group.index";
      this.mockRouterState.currentRoute.params = { name: "staff" };

      assert.true(
        this.evaluateCondition({
          pages: ["GROUP_PAGES"],
          params: { name: "staff" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["GROUP_PAGES"],
          params: { name: "moderators" },
        })
      );
    });
  });

  module("multiple page types (OR logic)", function () {
    test("matches when any page type matches", function (assert) {
      this.mockDiscoveryState.category = {
        id: 1,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general";

      assert.true(
        this.evaluateCondition({ pages: ["CATEGORY_PAGES", "TAG_PAGES"] })
      );
    });

    test("matches when second page type matches", function (assert) {
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = { name: "javascript" };
      this.mockRouterState.currentURL = "/tag/javascript";

      assert.true(
        this.evaluateCondition({ pages: ["CATEGORY_PAGES", "TAG_PAGES"] })
      );
    });

    test("does not match when no page type matches", function (assert) {
      this.mockDiscoveryState.category = null;
      this.mockDiscoveryState.tag = null;
      this.mockRouterState.currentURL = "/latest";
      this.mockRouterState.currentRouteName = "discovery.latest";

      assert.false(
        this.evaluateCondition({ pages: ["CATEGORY_PAGES", "TAG_PAGES"] })
      );
    });
  });

  module("queryParams matching", function () {
    test("matches queryParam with urls", function (assert) {
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

    test("matches queryParam with pages", function (assert) {
      this.mockDiscoveryState.category = {
        id: 1,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general?filter=latest";
      this.mockRouterState.currentRoute.queryParams = { filter: "latest" };

      assert.true(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          queryParams: { filter: "latest" },
        })
      );

      assert.false(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          queryParams: { filter: "top" },
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

  module("combined pages, params, and queryParams", function () {
    test("matches when pages, params, and queryParams all match", function (assert) {
      this.mockDiscoveryState.category = {
        id: 5,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general?solved=true";
      this.mockRouterState.currentRoute.queryParams = { solved: "true" };

      assert.true(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categoryId: 5 },
          queryParams: { solved: "true" },
        })
      );
    });

    test("fails when params match but queryParams do not", function (assert) {
      this.mockDiscoveryState.category = {
        id: 5,
        slug: "general",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/general?solved=false";
      this.mockRouterState.currentRoute.queryParams = { solved: "false" };

      assert.false(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categoryId: 5 },
          queryParams: { solved: "true" },
        })
      );
    });

    test("fails when page matches but params do not", function (assert) {
      this.mockDiscoveryState.category = {
        id: 10,
        slug: "other",
        parent_category_id: null,
      };
      this.mockRouterState.currentURL = "/c/other";

      assert.false(
        this.evaluateCondition({
          pages: ["CATEGORY_PAGES"],
          params: { categoryId: 5 },
        })
      );
    });
  });

  module("validate", function () {
    test("returns error when neither urls nor pages provided", function (assert) {
      const error = this.validateCondition({});
      assert.true(error?.message.includes("Must provide `urls` or `pages`"));
    });

    test("returns error for unknown page type", function (assert) {
      const error = this.validateCondition({ pages: ["INVALID_PAGE"] });
      assert.true(error?.message.includes("Unknown page type 'INVALID_PAGE'"));
      assert.strictEqual(error.path, "pages[0]");
    });

    test("suggests correction for typo in page type", function (assert) {
      const error = this.validateCondition({ pages: ["CATEGORY_PAGE"] });
      assert.true(error?.message.includes("Did you mean 'CATEGORY_PAGES'"));
    });

    test("returns error when params used without pages", function (assert) {
      const error = this.validateCondition({
        urls: ["/c/**"],
        params: { id: 5 },
      });
      assert.true(
        error?.message.includes("`params` requires `pages` to be specified")
      );
      assert.strictEqual(error.path, "params");
    });

    test("returns error when params used with urls", function (assert) {
      const error = this.validateCondition({
        pages: ["CATEGORY_PAGES"],
        urls: ["/c/**"],
        params: { id: 5 },
      });
      assert.true(
        error?.message.includes("`params` cannot be used with `urls`")
      );
      assert.strictEqual(error.path, "params");
    });

    test("returns error for invalid param for page type", function (assert) {
      const error = this.validateCondition({
        pages: ["CATEGORY_PAGES"],
        params: { filter: "latest" },
      });
      assert.true(
        error?.message.includes(
          "Parameter 'filter' is not valid for any of the listed page types"
        )
      );
      assert.strictEqual(error.path, "params");
    });

    test("returns error for param type mismatch (number expected, string given)", function (assert) {
      const error = this.validateCondition({
        pages: ["CATEGORY_PAGES"],
        params: { categoryId: "5" },
      });
      assert.true(
        error?.message.includes(
          "Parameter 'categoryId' must be a number, got string '5'"
        )
      );
      assert.strictEqual(error.path, "params.categoryId");
    });

    test("returns error for param type mismatch (string expected, number given)", function (assert) {
      const error = this.validateCondition({
        pages: ["TAG_PAGES"],
        params: { tagId: 123 },
      });
      assert.true(
        error?.message.includes(
          "Parameter 'tagId' must be a string, got number '123'"
        )
      );
      assert.strictEqual(error.path, "params.tagId");
    });

    test("returns error when param not valid for all listed page types", function (assert) {
      const error = this.validateCondition({
        pages: ["TAG_PAGES", "DISCOVERY_PAGES"],
        params: { tagId: "javascript" },
      });
      assert.true(
        error?.message.includes(
          "Parameter 'tagId' is not valid for all listed page types"
        )
      );
    });

    test("accepts params valid for all listed page types", function (assert) {
      assert.strictEqual(
        this.validateCondition({
          pages: ["DISCOVERY_PAGES", "TOP_MENU"],
          params: { filter: "latest" },
        }),
        null
      );
    });

    test("accepts categoryId param valid for both CATEGORY_PAGES and TAG_PAGES", function (assert) {
      assert.strictEqual(
        this.validateCondition({
          pages: ["CATEGORY_PAGES", "TAG_PAGES"],
          params: { categoryId: 5 },
        }),
        null
      );
    });

    test("returns error for page type names in urls", function (assert) {
      const error = this.validateCondition({ urls: ["CATEGORY_PAGES"] });
      assert.true(
        error?.message.includes(
          "Page shortcuts like 'CATEGORY_PAGES' are not supported in `urls`"
        )
      );
      assert.strictEqual(error.path, "urls[0]");
    });

    test("accepts valid page types", function (assert) {
      assert.strictEqual(
        this.validateCondition({ pages: ["CATEGORY_PAGES"] }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ pages: ["TAG_PAGES"] }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ pages: ["DISCOVERY_PAGES"] }),
        null
      );
      assert.strictEqual(this.validateCondition({ pages: ["HOMEPAGE"] }), null);
      assert.strictEqual(this.validateCondition({ pages: ["TOP_MENU"] }), null);
      assert.strictEqual(
        this.validateCondition({ pages: ["TOPIC_PAGES"] }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ pages: ["USER_PAGES"] }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ pages: ["ADMIN_PAGES"] }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ pages: ["GROUP_PAGES"] }),
        null
      );
    });

    test("accepts valid URL patterns", function (assert) {
      assert.strictEqual(this.validateCondition({ urls: ["/c/**"] }), null);
      assert.strictEqual(this.validateCondition({ urls: ["/t/*"] }), null);
    });

    test("returns error for invalid glob pattern in urls", function (assert) {
      const error = this.validateCondition({ urls: ["[unclosed"] });
      assert.true(error?.message.includes('Invalid glob pattern "[unclosed"'));
      assert.strictEqual(error.path, "urls[0]");
    });

    test("pages must be an array", function (assert) {
      const error = this.validateCondition({ pages: "CATEGORY_PAGES" });
      assert.true(
        error?.message.includes("`pages` must be an array of page type strings")
      );
      assert.strictEqual(error.path, "pages");
    });

    test("each page type must be a string", function (assert) {
      const error = this.validateCondition({ pages: [123] });
      assert.true(error?.message.includes("Each page type must be a string"));
      assert.strictEqual(error.path, "pages[0]");
    });
  });

  module("backslash escape for reserved keys", function () {
    test("\\\\any matches literal queryParam named 'any'", function (assert) {
      this.mockRouterState.currentURL = "/latest?any=some-value";
      this.mockRouterState.currentRoute.queryParams = { any: "some-value" };

      assert.true(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { "\\any": "some-value" },
        })
      );

      assert.false(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { "\\any": "other-value" },
        })
      );
    });

    test("\\\\not matches literal queryParam named 'not'", function (assert) {
      this.mockRouterState.currentURL = "/latest?not=some-value";
      this.mockRouterState.currentRoute.queryParams = { not: "some-value" };

      assert.true(
        this.evaluateCondition({
          urls: ["/latest"],
          queryParams: { "\\not": "some-value" },
        })
      );
    });
  });
});
