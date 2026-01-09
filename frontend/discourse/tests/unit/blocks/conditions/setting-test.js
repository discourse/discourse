import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockSettingCondition from "discourse/blocks/conditions/setting";

module("Unit | Blocks | Conditions | setting", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const testOwner = getOwner(this);

    // Mock site settings
    this.mockSiteSettings = {
      enable_badges: true,
      enable_whispers: false,
      desktop_category_page_style: "categories_and_latest_topics",
      top_menu: "latest|new|unread|categories",
      share_links: "twitter|facebook|email",
    };

    // Create mock site settings service
    const mockSiteSettings = this.mockSiteSettings;
    class MockSiteSettings extends Service {
      get enable_badges() {
        return mockSiteSettings.enable_badges;
      }

      get enable_whispers() {
        return mockSiteSettings.enable_whispers;
      }

      get desktop_category_page_style() {
        return mockSiteSettings.desktop_category_page_style;
      }

      get top_menu() {
        return mockSiteSettings.top_menu;
      }

      get share_links() {
        return mockSiteSettings.share_links;
      }
    }
    testOwner.unregister("service:site-settings");
    testOwner.register("service:site-settings", MockSiteSettings);

    // Store owner for creating condition instances
    this.testOwner = testOwner;

    // Helper to evaluate setting condition directly
    this.evaluateCondition = (args) => {
      const condition = new BlockSettingCondition();
      setOwner(condition, testOwner);
      return condition.evaluate(args);
    };

    // Helper to validate setting condition (returns error or null)
    this.validateCondition = (args) => {
      const condition = new BlockSettingCondition();
      setOwner(condition, testOwner);
      return condition.validate(args);
    };
  });

  module("with site settings (existing behavior)", function () {
    test("enabled: true passes when setting is truthy", function (assert) {
      assert.true(
        this.evaluateCondition({
          name: "enable_badges",
          enabled: true,
        })
      );
    });

    test("enabled: true fails when setting is falsy", function (assert) {
      assert.false(
        this.evaluateCondition({
          name: "enable_whispers",
          enabled: true,
        })
      );
    });

    test("enabled: false passes when setting is falsy", function (assert) {
      assert.true(
        this.evaluateCondition({
          name: "enable_whispers",
          enabled: false,
        })
      );
    });

    test("equals matches exact value", function (assert) {
      assert.true(
        this.evaluateCondition({
          name: "desktop_category_page_style",
          equals: "categories_and_latest_topics",
        })
      );

      assert.false(
        this.evaluateCondition({
          name: "desktop_category_page_style",
          equals: "categories_only",
        })
      );
    });

    test("includes matches if setting is in array", function (assert) {
      assert.true(
        this.evaluateCondition({
          name: "desktop_category_page_style",
          includes: [
            "categories_and_latest_topics",
            "categories_and_top_topics",
          ],
        })
      );

      assert.false(
        this.evaluateCondition({
          name: "desktop_category_page_style",
          includes: ["categories_only", "categories_boxes"],
        })
      );
    });

    test("contains matches if list setting contains value", function (assert) {
      assert.true(
        this.evaluateCondition({
          name: "top_menu",
          contains: "latest",
        })
      );

      assert.false(
        this.evaluateCondition({
          name: "top_menu",
          contains: "hot",
        })
      );
    });

    test("containsAny matches if list setting contains any value", function (assert) {
      assert.true(
        this.evaluateCondition({
          name: "share_links",
          containsAny: ["twitter", "linkedin"],
        })
      );

      assert.false(
        this.evaluateCondition({
          name: "share_links",
          containsAny: ["linkedin", "reddit"],
        })
      );
    });
  });

  module("with explicit source object (theme settings)", function () {
    test("enabled: true passes when custom setting is truthy", function (assert) {
      const themeSettings = {
        show_sidebar: true,
        enable_animations: false,
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "show_sidebar",
          enabled: true,
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "enable_animations",
          enabled: true,
        })
      );
    });

    test("enabled: false passes when custom setting is falsy", function (assert) {
      const themeSettings = {
        show_sidebar: true,
        enable_animations: false,
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "enable_animations",
          enabled: false,
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "show_sidebar",
          enabled: false,
        })
      );
    });

    test("equals matches exact value in custom settings", function (assert) {
      const themeSettings = {
        theme_color: "dark",
        layout_style: "compact",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "theme_color",
          equals: "dark",
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "theme_color",
          equals: "light",
        })
      );
    });

    test("includes matches if custom setting is in array", function (assert) {
      const themeSettings = {
        icon_style: "outline",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "icon_style",
          includes: ["outline", "filled"],
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "icon_style",
          includes: ["filled", "duotone"],
        })
      );
    });

    test("contains matches if custom list setting contains value", function (assert) {
      const themeSettings = {
        enabled_features: "sidebar|dark-mode|animations",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "enabled_features",
          contains: "dark-mode",
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "enabled_features",
          contains: "tooltips",
        })
      );
    });

    test("containsAny matches if custom list setting contains any value", function (assert) {
      const themeSettings = {
        enabled_modules: "header|footer|sidebar",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "enabled_modules",
          containsAny: ["header", "navigation"],
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "enabled_modules",
          containsAny: ["navigation", "search"],
        })
      );
    });

    test("handles missing setting key in custom settings", function (assert) {
      const themeSettings = {
        existing_key: true,
      };

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "missing_key",
          enabled: true,
        })
      );
    });

    test("handles null source object gracefully", function (assert) {
      assert.false(
        this.evaluateCondition({
          source: null,
          name: "any_setting",
          enabled: true,
        }),
        "enabled: true fails with null source"
      );

      assert.true(
        this.evaluateCondition({
          source: null,
          name: "any_setting",
          enabled: false,
        }),
        "enabled: false passes with null source (setting is undefined/falsy)"
      );
    });

    test("handles undefined source value gracefully", function (assert) {
      const themeSettings = {};

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "undefined_setting",
        }),
        "undefined setting value is falsy"
      );

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "undefined_setting",
          enabled: false,
        }),
        "enabled: false passes for undefined setting"
      );
    });

    test("evaluates truthy by default when no condition type specified", function (assert) {
      const themeSettings = {
        some_setting: "has-value",
        empty_setting: "",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "some_setting",
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "empty_setting",
        })
      );
    });
  });

  module("validate", function () {
    test("returns error when name argument is missing", function (assert) {
      const error = this.validateCondition({});
      assert.true(error?.message.includes("`name` argument is required"));
      assert.strictEqual(error.path, "name");
    });

    test("returns error when multiple condition types are provided", function (assert) {
      const error = this.validateCondition({
        name: "enable_badges",
        enabled: true,
        equals: "some-value",
      });
      assert.true(
        error?.message.includes("Cannot use multiple condition types")
      );
    });

    test("returns error when enabled and includes are both provided", function (assert) {
      const error = this.validateCondition({
        name: "enable_badges",
        enabled: true,
        includes: ["value1", "value2"],
      });
      assert.true(
        error?.message.includes("Cannot use multiple condition types")
      );
    });

    test("returns error for unknown site setting", function (assert) {
      const error = this.validateCondition({ name: "nonexistent_setting" });
      assert.true(error?.message.includes("Unknown site setting"));
      assert.strictEqual(error.path, "name");
    });

    test("does not return error for unknown setting when custom source provided", function (assert) {
      assert.strictEqual(
        this.validateCondition({
          source: { custom_key: true },
          name: "custom_key",
        }),
        null
      );
    });

    test("accepts valid site setting", function (assert) {
      assert.strictEqual(
        this.validateCondition({ name: "enable_badges", enabled: true }),
        null
      );
    });
  });

  module("type coercion", function () {
    test("contains matches number searchValue against string list", function (assert) {
      const themeSettings = {
        allowed_ids: "123|456|789",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "allowed_ids",
          contains: 123,
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "allowed_ids",
          contains: 999,
        })
      );
    });

    test("containsAny matches number searchValues against string list", function (assert) {
      const themeSettings = {
        allowed_ids: "123|456|789",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "allowed_ids",
          containsAny: [123, 999],
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "allowed_ids",
          containsAny: [111, 222],
        })
      );
    });

    test("contains matches number searchValue against array setting", function (assert) {
      const themeSettings = {
        allowed_ids: [123, 456, 789],
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "allowed_ids",
          contains: "123",
        })
      );
    });
  });
});
