import { getOwner, setOwner } from "@ember/owner";
import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockSettingCondition from "discourse/blocks/conditions/setting";
import { validateConditions } from "discourse/lib/blocks/-internals/validation/conditions";

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

    // Helper to validate via infrastructure
    this.validateCondition = (args) => {
      const condition = new BlockSettingCondition();
      setOwner(condition, testOwner);

      // Create a map with the condition instance
      const conditionTypes = new Map([["setting", condition]]);

      try {
        validateConditions({ type: "setting", ...args }, conditionTypes);
        return null;
      } catch (error) {
        return error;
      }
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
        "enabled: true returns false with null source"
      );

      assert.false(
        this.evaluateCondition({
          source: null,
          name: "any_setting",
          enabled: false,
        }),
        "enabled: false returns false with null source (source is invalid)"
      );
    });

    test("handles undefined source value gracefully", function (assert) {
      const themeSettings = {};

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "undefined_setting",
          enabled: true,
        }),
        "undefined setting returns false (setting doesn't exist)"
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "undefined_setting",
          enabled: false,
        }),
        "enabled: false returns false for non-existent setting"
      );
    });

    test("evaluates truthy using enabled: true", function (assert) {
      const themeSettings = {
        some_setting: "has-value",
        empty_setting: "",
      };

      assert.true(
        this.evaluateCondition({
          source: themeSettings,
          name: "some_setting",
          enabled: true,
        })
      );

      assert.false(
        this.evaluateCondition({
          source: themeSettings,
          name: "empty_setting",
          enabled: true,
        })
      );
    });
  });

  module("validate (through infrastructure)", function () {
    test("returns error when name argument is missing", function (assert) {
      const error = this.validateCondition({});
      assert.true(error?.message.includes("missing required arg"));
    });

    test("typo in required arg produces unknown arg error with suggestion, not missing required error", function (assert) {
      // Typo: "nam" instead of "name"
      const error = this.validateCondition({ nam: "enable_badges" });

      // Should say "unknown" not "missing required"
      assert.true(
        error?.message.includes("unknown arg"),
        "error should mention unknown arg"
      );
      assert.false(
        error?.message.includes("missing required"),
        "error should NOT mention missing required"
      );
      assert.true(
        error?.message.includes('did you mean "name"'),
        "error should suggest the correct arg name"
      );
    });

    test("returns error when multiple condition types are provided (exactlyOne constraint)", function (assert) {
      const error = this.validateCondition({
        name: "enable_badges",
        enabled: true,
        equals: "some-value",
      });
      assert.true(error?.message.includes("exactly one of"));
    });

    test("returns error when enabled and includes are both provided", function (assert) {
      const error = this.validateCondition({
        name: "enable_badges",
        enabled: true,
        includes: ["value1", "value2"],
      });
      assert.true(error?.message.includes("exactly one of"));
    });

    test("returns error when no condition type is provided (exactlyOne constraint)", function (assert) {
      const error = this.validateCondition({
        name: "enable_badges",
      });
      assert.true(error?.message.includes("exactly one of"));
    });

    test("constraint error path points to condition type for better error location", function (assert) {
      const error = this.validateCondition({
        name: "enable_badges",
        // Missing required arg: enabled, equals, includes, contains, or containsAny
      });

      // The error path should include "type" so the error location indicator
      // points to the condition (identified by its type) rather than the block
      assert.strictEqual(
        error?.path,
        "type",
        "constraint error path should point to the condition's type property"
      );
    });

    test("constraint error path includes array index when condition is in an array", function (assert) {
      const condition = new BlockSettingCondition();
      setOwner(condition, this.testOwner);
      const conditionTypes = new Map([["setting", condition]]);

      let error;
      try {
        // Array of conditions - the second one has a constraint error
        validateConditions(
          [
            { type: "setting", name: "enable_badges", enabled: true },
            { type: "setting", name: "enable_whispers" }, // Missing condition type arg
          ],
          conditionTypes
        );
      } catch (e) {
        error = e;
      }

      // Path should include the array index and point to the type
      assert.strictEqual(
        error?.path,
        "[1].type",
        "constraint error path should include array index and type"
      );
    });

    test("accepts valid site setting", function (assert) {
      assert.strictEqual(
        this.validateCondition({ name: "enable_badges", enabled: true }),
        null
      );
    });

    test("returns error when enabled is not a boolean", function (assert) {
      const error = this.validateCondition({
        name: "enable_badges",
        enabled: "true",
      });
      assert.true(error?.message.includes("must be a boolean"));
    });

    test("returns error when includes is not an array", function (assert) {
      const error = this.validateCondition({
        name: "desktop_category_page_style",
        includes: "categories_only",
      });
      assert.true(error?.message.includes("must be an array"));
    });

    test("returns error when containsAny is not an array", function (assert) {
      const error = this.validateCondition({
        name: "top_menu",
        containsAny: "latest",
      });
      assert.true(error?.message.includes("must be an array"));
    });
  });

  module("getResolvedValueForLogging", function () {
    test("returns setting value when setting exists", function (assert) {
      const condition = new BlockSettingCondition();
      setOwner(condition, this.testOwner);

      const result = condition.getResolvedValueForLogging({
        name: "enable_badges",
      });

      assert.deepEqual(result, { value: true, hasValue: true });
    });

    test("returns note when setting does not exist", function (assert) {
      const condition = new BlockSettingCondition();
      setOwner(condition, this.testOwner);

      // Use a custom source with enumerable properties
      const settings = { existing_setting: true };
      const result = condition.getResolvedValueForLogging({
        source: settings,
        name: "nonexistent_setting",
      });

      assert.strictEqual(result.value, undefined);
      assert.true(result.hasValue);
      assert.true(result.note.includes('"nonexistent_setting" does not exist'));
    });

    test("suggests similar setting name in note", function (assert) {
      const condition = new BlockSettingCondition();
      setOwner(condition, this.testOwner);

      // Use a custom source with enumerable properties
      const settings = { enable_badges: true, enable_whispers: false };
      const result = condition.getResolvedValueForLogging({
        source: settings,
        name: "enable_badgez", // typo - similar to "enable_badges"
      });

      assert.strictEqual(result.value, undefined);
      assert.true(result.hasValue);
      assert.true(result.note.includes('did you mean "enable_badges"'));
    });

    test("returns note when settings source is null", function (assert) {
      const condition = new BlockSettingCondition();
      setOwner(condition, this.testOwner);

      const result = condition.getResolvedValueForLogging({
        source: null,
        name: "any_setting",
      });

      assert.deepEqual(result, {
        value: undefined,
        hasValue: true,
        note: "settings source is null/undefined",
      });
    });

    test("returns value from custom source when setting exists", function (assert) {
      const condition = new BlockSettingCondition();
      setOwner(condition, this.testOwner);

      const themeSettings = { my_setting: "custom_value" };
      const result = condition.getResolvedValueForLogging({
        source: themeSettings,
        name: "my_setting",
      });

      assert.deepEqual(result, { value: "custom_value", hasValue: true });
    });

    test("returns note with suggestion from custom source", function (assert) {
      const condition = new BlockSettingCondition();
      setOwner(condition, this.testOwner);

      const themeSettings = { my_setting: "value" };
      const result = condition.getResolvedValueForLogging({
        source: themeSettings,
        name: "my_settin", // typo
      });

      assert.strictEqual(result.value, undefined);
      assert.true(result.hasValue);
      assert.true(result.note.includes('did you mean "my_setting"'));
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
