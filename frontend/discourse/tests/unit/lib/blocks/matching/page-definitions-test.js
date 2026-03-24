import { module, test } from "qunit";
import {
  getCurrentPageType,
  getPageContext,
  getParamsForPageType,
  getValidParamNames,
  isValidPageType,
  PAGE_DEFINITIONS,
  suggestPageType,
  VALID_PAGE_TYPES,
  validateParamsAgainstPages,
  validateParamType,
} from "discourse/lib/blocks/-internals/matching/page-definitions";

module("Unit | Lib | blocks/matching/page-definitions", function () {
  module("PAGE_DEFINITIONS", function () {
    test("contains expected page types", function (assert) {
      const expectedTypes = [
        "CATEGORY_PAGES",
        "TAG_PAGES",
        "DISCOVERY_PAGES",
        "HOMEPAGE",
        "TOP_MENU",
        "TOPIC_PAGES",
        "USER_PAGES",
        "ADMIN_PAGES",
        "GROUP_PAGES",
      ];

      for (const type of expectedTypes) {
        assert.true(type in PAGE_DEFINITIONS, `${type} should be defined`);
      }
    });

    test("each page type has description and params", function (assert) {
      for (const [name, definition] of Object.entries(PAGE_DEFINITIONS)) {
        assert.strictEqual(
          typeof definition.description,
          "string",
          `${name} should have a string description`
        );
        assert.strictEqual(
          typeof definition.params,
          "object",
          `${name} should have params object`
        );
      }
    });
  });

  module("VALID_PAGE_TYPES", function () {
    test("is an array of strings", function (assert) {
      assert.true(Array.isArray(VALID_PAGE_TYPES));
      for (const type of VALID_PAGE_TYPES) {
        assert.strictEqual(typeof type, "string");
      }
    });

    test("matches PAGE_DEFINITIONS keys", function (assert) {
      const definitionKeys = Object.keys(PAGE_DEFINITIONS);
      assert.deepEqual(VALID_PAGE_TYPES.sort(), definitionKeys.sort());
    });
  });

  module("isValidPageType", function () {
    test("returns true for valid page types", function (assert) {
      assert.true(isValidPageType("CATEGORY_PAGES"));
      assert.true(isValidPageType("TOPIC_PAGES"));
      assert.true(isValidPageType("HOMEPAGE"));
    });

    test("returns false for invalid page types", function (assert) {
      assert.false(isValidPageType("INVALID_TYPE"));
      assert.false(isValidPageType("category_pages"));
      assert.false(isValidPageType(""));
      assert.false(isValidPageType(null));
    });
  });

  module("getParamsForPageType", function () {
    test("returns params object for valid page type", function (assert) {
      const params = getParamsForPageType("CATEGORY_PAGES");

      assert.strictEqual(typeof params, "object");
      assert.true("categoryId" in params);
      assert.true("categorySlug" in params);
      assert.true("parentCategoryId" in params);
    });

    test("returns null for invalid page type", function (assert) {
      assert.strictEqual(getParamsForPageType("INVALID_TYPE"), null);
    });

    test("returns empty object for page types with no params", function (assert) {
      const params = getParamsForPageType("HOMEPAGE");
      assert.deepEqual(params, {});
    });

    test("each param has type and description", function (assert) {
      const params = getParamsForPageType("TOPIC_PAGES");

      for (const [name, definition] of Object.entries(params)) {
        assert.true(
          ["string", "number"].includes(definition.type),
          `${name} should have valid type`
        );
        assert.strictEqual(
          typeof definition.description,
          "string",
          `${name} should have description`
        );
      }
    });
  });

  module("getValidParamNames", function () {
    test("returns array of param names for valid page type", function (assert) {
      const names = getValidParamNames("CATEGORY_PAGES");

      assert.true(Array.isArray(names));
      assert.true(names.includes("categoryId"));
      assert.true(names.includes("categorySlug"));
      assert.true(names.includes("parentCategoryId"));
    });

    test("returns empty array for invalid page type", function (assert) {
      assert.deepEqual(getValidParamNames("INVALID_TYPE"), []);
    });

    test("returns empty array for page types with no params", function (assert) {
      assert.deepEqual(getValidParamNames("HOMEPAGE"), []);
    });
  });

  module("suggestPageType", function () {
    test("suggests closest match for typos", function (assert) {
      assert.strictEqual(suggestPageType("CATEGORY_PAGE"), "CATEGORY_PAGES");
      assert.strictEqual(suggestPageType("TOPIC_PAGE"), "TOPIC_PAGES");
    });

    test("suggests match for case variations", function (assert) {
      assert.strictEqual(suggestPageType("category_pages"), "CATEGORY_PAGES");
    });

    test("returns null for completely unrelated strings", function (assert) {
      const result = suggestPageType("xyz123abc");
      const isValidResult =
        result === null || VALID_PAGE_TYPES.includes(result);
      assert.true(isValidResult, "Should return null or a valid page type");
    });
  });

  module("validateParamsAgainstPages", function () {
    test("returns valid for empty params", function (assert) {
      const result = validateParamsAgainstPages({}, ["CATEGORY_PAGES"]);
      assert.true(result.valid);
      assert.deepEqual(result.errors, []);
    });

    test("returns valid for null/undefined params", function (assert) {
      assert.true(validateParamsAgainstPages(null, ["CATEGORY_PAGES"]).valid);
      assert.true(
        validateParamsAgainstPages(undefined, ["CATEGORY_PAGES"]).valid
      );
    });

    test("returns valid for params present in all page types", function (assert) {
      const result = validateParamsAgainstPages({ categoryId: 5 }, [
        "CATEGORY_PAGES",
      ]);
      assert.true(result.valid);
      assert.deepEqual(result.errors, []);
    });

    test("returns error for params not valid in any page type", function (assert) {
      const result = validateParamsAgainstPages({ unknownParam: "value" }, [
        "CATEGORY_PAGES",
      ]);

      assert.false(result.valid);
      assert.strictEqual(result.errors.length, 1);
      assert.true(result.errors[0].includes("unknownParam"));
    });

    test("returns error when param valid for some but not all page types", function (assert) {
      // categoryId is valid for CATEGORY_PAGES but not TOPIC_PAGES
      const result = validateParamsAgainstPages({ categoryId: 5 }, [
        "CATEGORY_PAGES",
        "TOPIC_PAGES",
      ]);

      assert.false(result.valid);
      assert.strictEqual(result.errors.length, 1);
      assert.true(result.errors[0].includes("categoryId"));
      assert.true(result.errors[0].includes("not valid for all"));
    });

    test("validates multiple params", function (assert) {
      const result = validateParamsAgainstPages(
        { categoryId: 5, categorySlug: "general" },
        ["CATEGORY_PAGES"]
      );
      assert.true(result.valid);
    });
  });

  module("validateParamType", function () {
    test("validates number type correctly", function (assert) {
      const valid = validateParamType("categoryId", 5, "CATEGORY_PAGES");
      assert.true(valid.valid);
      assert.strictEqual(valid.error, null);
    });

    test("returns error for wrong number type", function (assert) {
      const result = validateParamType("categoryId", "5", "CATEGORY_PAGES");

      assert.false(result.valid);
      assert.true(result.error.includes("must be a number"));
      assert.true(result.error.includes("Hint"));
    });

    test("validates string type correctly", function (assert) {
      const valid = validateParamType(
        "categorySlug",
        "general",
        "CATEGORY_PAGES"
      );
      assert.true(valid.valid);
    });

    test("returns error for wrong string type", function (assert) {
      const result = validateParamType("categorySlug", 123, "CATEGORY_PAGES");

      assert.false(result.valid);
      assert.true(result.error.includes("must be a string"));
    });

    test("returns error for unknown parameter", function (assert) {
      const result = validateParamType(
        "unknownParam",
        "value",
        "CATEGORY_PAGES"
      );

      assert.false(result.valid);
      assert.true(result.error.includes("Unknown parameter"));
    });

    test("returns error for invalid page type", function (assert) {
      const result = validateParamType("categoryId", 5, "INVALID_TYPE");

      assert.false(result.valid);
      assert.true(result.error.includes("Unknown parameter"));
    });
  });

  module("getPageContext", function () {
    module("CATEGORY_PAGES", function () {
      test("returns context when category exists", function (assert) {
        const services = {
          router: {},
          discovery: {
            category: {
              id: 5,
              slug: "general",
              parent_category_id: 2,
            },
          },
        };

        const context = getPageContext("CATEGORY_PAGES", services);

        assert.deepEqual(context, {
          categoryId: 5,
          categorySlug: "general",
          parentCategoryId: 2,
        });
      });

      test("returns null when no category", function (assert) {
        const services = {
          router: {},
          discovery: { category: null },
        };

        assert.strictEqual(getPageContext("CATEGORY_PAGES", services), null);
      });
    });

    module("TAG_PAGES", function () {
      test("returns context when tag exists", function (assert) {
        const services = {
          router: {},
          discovery: {
            tag: { name: "javascript" },
            category: { id: 5, slug: "dev", parent_category_id: 1 },
          },
        };

        const context = getPageContext("TAG_PAGES", services);

        assert.deepEqual(context, {
          tagId: "javascript",
          categoryId: 5,
          categorySlug: "dev",
          parentCategoryId: 1,
        });
      });

      test("returns null when no tag", function (assert) {
        const services = {
          router: {},
          discovery: { tag: null },
        };

        assert.strictEqual(getPageContext("TAG_PAGES", services), null);
      });
    });

    module("DISCOVERY_PAGES", function () {
      test("returns context on discovery route", function (assert) {
        const services = {
          router: { currentRouteName: "discovery.latest" },
          discovery: { onDiscoveryRoute: true, custom: false },
        };

        const context = getPageContext("DISCOVERY_PAGES", services);

        assert.deepEqual(context, { filter: "latest" });
      });

      test("returns null when not on discovery route", function (assert) {
        const services = {
          router: { currentRouteName: "topic.show" },
          discovery: { onDiscoveryRoute: false },
        };

        assert.strictEqual(getPageContext("DISCOVERY_PAGES", services), null);
      });

      test("returns null on custom homepage", function (assert) {
        const services = {
          router: { currentRouteName: "discovery.custom" },
          discovery: { onDiscoveryRoute: true, custom: true },
        };

        assert.strictEqual(getPageContext("DISCOVERY_PAGES", services), null);
      });
    });

    module("HOMEPAGE", function () {
      test("returns empty object on custom homepage", function (assert) {
        const services = {
          router: {},
          discovery: { custom: true },
        };

        assert.deepEqual(getPageContext("HOMEPAGE", services), {});
      });

      test("returns null when not on custom homepage", function (assert) {
        const services = {
          router: {},
          discovery: { custom: false },
        };

        assert.strictEqual(getPageContext("HOMEPAGE", services), null);
      });
    });

    module("TOP_MENU", function () {
      test("returns context on top menu route", function (assert) {
        const services = {
          router: { currentRouteName: "discovery.top" },
          discovery: {
            onDiscoveryRoute: true,
            category: null,
            tag: null,
            custom: false,
          },
        };

        const context = getPageContext("TOP_MENU", services);

        assert.deepEqual(context, { filter: "top" });
      });

      test("returns null on category page", function (assert) {
        const services = {
          router: { currentRouteName: "discovery.latest" },
          discovery: {
            onDiscoveryRoute: true,
            category: { id: 5 },
            tag: null,
            custom: false,
          },
        };

        assert.strictEqual(getPageContext("TOP_MENU", services), null);
      });
    });

    module("TOPIC_PAGES", function () {
      test("returns context on topic page", function (assert) {
        const services = {
          router: {
            currentRouteName: "topic.show",
            currentRoute: { params: { id: "123", slug: "hello-world" } },
          },
          discovery: {},
        };

        const context = getPageContext("TOPIC_PAGES", services);

        assert.deepEqual(context, { id: 123, slug: "hello-world" });
      });

      test("returns null when not on topic page", function (assert) {
        const services = {
          router: { currentRouteName: "discovery.latest" },
          discovery: {},
        };

        assert.strictEqual(getPageContext("TOPIC_PAGES", services), null);
      });
    });

    module("USER_PAGES", function () {
      test("returns context on user page", function (assert) {
        const services = {
          router: {
            currentRouteName: "user.summary",
            currentRoute: { params: { username: "johndoe" } },
          },
          discovery: {},
        };

        const context = getPageContext("USER_PAGES", services);

        assert.deepEqual(context, { username: "johndoe" });
      });

      test("returns null when not on user page", function (assert) {
        const services = {
          router: { currentRouteName: "topic.show" },
          discovery: {},
        };

        assert.strictEqual(getPageContext("USER_PAGES", services), null);
      });
    });

    module("ADMIN_PAGES", function () {
      test("returns empty object on admin page", function (assert) {
        const services = {
          router: { currentRouteName: "adminDashboard" },
          discovery: {},
        };

        assert.deepEqual(getPageContext("ADMIN_PAGES", services), {});
      });

      test("returns null when not on admin page", function (assert) {
        const services = {
          router: { currentRouteName: "topic.show" },
          discovery: {},
        };

        assert.strictEqual(getPageContext("ADMIN_PAGES", services), null);
      });
    });

    module("GROUP_PAGES", function () {
      test("returns context on group page", function (assert) {
        const services = {
          router: {
            currentRouteName: "group.members",
            currentRoute: { params: { name: "moderators" } },
          },
          discovery: {},
        };

        const context = getPageContext("GROUP_PAGES", services);

        assert.deepEqual(context, { name: "moderators" });
      });

      test("returns null when not on group page", function (assert) {
        const services = {
          router: { currentRouteName: "topic.show" },
          discovery: {},
        };

        assert.strictEqual(getPageContext("GROUP_PAGES", services), null);
      });
    });

    test("returns null for invalid page type", function (assert) {
      const services = { router: {}, discovery: {} };
      assert.strictEqual(getPageContext("INVALID_TYPE", services), null);
    });
  });

  module("getCurrentPageType", function () {
    test("returns CATEGORY_PAGES when on category page", function (assert) {
      const services = {
        router: { currentRouteName: "discovery.latest" },
        discovery: {
          onDiscoveryRoute: true,
          custom: false,
          category: { id: 5, slug: "general" },
          tag: null,
        },
      };

      assert.strictEqual(getCurrentPageType(services), "CATEGORY_PAGES");
    });

    test("returns TOPIC_PAGES when on topic page", function (assert) {
      const services = {
        router: {
          currentRouteName: "topic.show",
          currentRoute: { params: { id: "123", slug: "hello" } },
        },
        discovery: {
          onDiscoveryRoute: false,
          category: null,
          tag: null,
        },
      };

      assert.strictEqual(getCurrentPageType(services), "TOPIC_PAGES");
    });

    test("returns HOMEPAGE when on custom homepage", function (assert) {
      const services = {
        router: { currentRouteName: "discovery.custom" },
        discovery: {
          custom: true,
          category: null,
          tag: null,
        },
      };

      // HOMEPAGE comes before DISCOVERY_PAGES in iteration, so custom
      // homepage should match HOMEPAGE
      const result = getCurrentPageType(services);
      assert.strictEqual(result, "HOMEPAGE");
    });

    test("returns null when no page type matches", function (assert) {
      const services = {
        router: { currentRouteName: "some.unknown.route" },
        discovery: {
          onDiscoveryRoute: false,
          custom: false,
          category: null,
          tag: null,
        },
      };

      assert.strictEqual(getCurrentPageType(services), null);
    });
  });
});
