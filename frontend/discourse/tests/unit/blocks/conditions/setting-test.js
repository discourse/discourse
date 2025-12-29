import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { BlockConditionValidationError } from "discourse/blocks/conditions";
import BlockSettingCondition from "discourse/blocks/conditions/setting";

module("Unit | Blocks | Condition | setting", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockSettingCondition();
    setOwner(this.condition, getOwner(this));
    this.siteSettings = getOwner(this).lookup("service:site-settings");
  });

  module("validate", function () {
    test("throws when setting argument is missing", function (assert) {
      assert.throws(
        () => this.condition.validate({}),
        BlockConditionValidationError
      );
    });

    test("throws when setting does not exist", function (assert) {
      assert.throws(
        () => this.condition.validate({ setting: "nonexistent_setting_xyz" }),
        BlockConditionValidationError
      );
    });

    test("throws when multiple condition types are used", function (assert) {
      assert.throws(
        () =>
          this.condition.validate({
            setting: "title",
            enabled: true,
            equals: "foo",
          }),
        BlockConditionValidationError
      );

      assert.throws(
        () =>
          this.condition.validate({
            setting: "title",
            includes: ["a", "b"],
            contains: "a",
          }),
        BlockConditionValidationError
      );
    });

    test("passes with valid setting configurations", function (assert) {
      this.condition.validate({ setting: "title" });
      this.condition.validate({ setting: "title", enabled: true });
      this.condition.validate({ setting: "title", enabled: false });
      this.condition.validate({ setting: "title", equals: "My Site" });
      this.condition.validate({ setting: "title", includes: ["A", "B"] });
      assert.true(true, "all valid configurations passed");
    });
  });

  module("evaluate", function () {
    test("enabled: true checks for truthy value", function (assert) {
      const originalTitle = this.siteSettings.title;

      this.siteSettings.title = "My Site";
      assert.true(this.condition.evaluate({ setting: "title", enabled: true }));

      this.siteSettings.title = "";
      assert.false(
        this.condition.evaluate({ setting: "title", enabled: true })
      );

      this.siteSettings.title = originalTitle;
    });

    test("enabled: false checks for falsy value", function (assert) {
      const originalTitle = this.siteSettings.title;

      this.siteSettings.title = "";
      assert.true(
        this.condition.evaluate({ setting: "title", enabled: false })
      );

      this.siteSettings.title = "My Site";
      assert.false(
        this.condition.evaluate({ setting: "title", enabled: false })
      );

      this.siteSettings.title = originalTitle;
    });

    test("equals checks for exact value", function (assert) {
      const originalTitle = this.siteSettings.title;

      this.siteSettings.title = "Test Site";
      assert.true(
        this.condition.evaluate({ setting: "title", equals: "Test Site" })
      );
      assert.false(
        this.condition.evaluate({ setting: "title", equals: "Other Site" })
      );

      this.siteSettings.title = originalTitle;
    });

    test("includes checks if value is in array", function (assert) {
      const originalTitle = this.siteSettings.title;

      this.siteSettings.title = "Option B";
      assert.true(
        this.condition.evaluate({
          setting: "title",
          includes: ["Option A", "Option B", "Option C"],
        })
      );
      assert.false(
        this.condition.evaluate({
          setting: "title",
          includes: ["Option A", "Option C"],
        })
      );

      this.siteSettings.title = originalTitle;
    });

    test("no condition returns truthy check", function (assert) {
      const originalTitle = this.siteSettings.title;

      this.siteSettings.title = "My Site";
      assert.true(this.condition.evaluate({ setting: "title" }));

      this.siteSettings.title = "";
      assert.false(this.condition.evaluate({ setting: "title" }));

      this.siteSettings.title = originalTitle;
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockSettingCondition.type, "setting");
    });
  });
});
