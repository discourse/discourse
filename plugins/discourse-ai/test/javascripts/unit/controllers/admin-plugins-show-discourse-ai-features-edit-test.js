import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module(
  "Unit | Controller | admin-plugins/show/discourse-ai-features/edit",
  function (hooks) {
    setupTest(hooks);

    test("getValidationFor returns correct validation for integer with min/max", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      const setting = {
        type: "integer",
        min: 0,
        max: 100,
      };

      const validation = controller.getValidationFor(setting);

      assert.strictEqual(
        validation,
        "number|between:0,100",
        "should return number with between validator"
      );
    });

    test("getValidationFor returns correct validation for integer with only min", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      const setting = {
        type: "integer",
        min: 5,
      };

      const validation = controller.getValidationFor(setting);

      assert.strictEqual(
        validation,
        "number|between:5,",
        "should return number with between validator (min only)"
      );
    });

    test("getValidationFor returns correct validation for integer with only max", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      const setting = {
        type: "integer",
        max: 50,
      };

      const validation = controller.getValidationFor(setting);

      assert.strictEqual(
        validation,
        "number|between:,50",
        "should return number with between validator (max only)"
      );
    });

    test("getValidationFor returns number for integer without constraints", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      const setting = {
        type: "integer",
      };

      const validation = controller.getValidationFor(setting);

      assert.strictEqual(
        validation,
        "number",
        "should return just number validator"
      );
    });

    test("getValidationFor returns undefined for non-integer types", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      const setting = {
        type: "string",
      };

      const validation = controller.getValidationFor(setting);

      assert.strictEqual(
        validation,
        undefined,
        "should return undefined for non-integer types"
      );
    });

    test("valuesEqual compares using toString", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      assert.true(
        controller.valuesEqual("123", 123),
        "string '123' should equal number 123"
      );
      assert.true(
        controller.valuesEqual(true, "true"),
        "boolean true should equal string 'true'"
      );
      assert.true(
        controller.valuesEqual(false, "false"),
        "boolean false should equal string 'false'"
      );
      assert.true(
        controller.valuesEqual("abc", "abc"),
        "identical strings should be equal"
      );
      assert.false(
        controller.valuesEqual("123", "456"),
        "different values should not be equal"
      );
    });

    test("valuesEqual handles null and undefined", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      assert.false(
        controller.valuesEqual(null, "null"),
        "null should not equal string 'null'"
      );
      assert.false(
        controller.valuesEqual(undefined, "undefined"),
        "undefined should not equal string 'undefined'"
      );
      assert.true(controller.valuesEqual(null, null), "null should equal null");
      assert.true(
        controller.valuesEqual(undefined, undefined),
        "undefined should equal undefined"
      );
    });

    test("findSetting returns correct setting by name", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      controller.settings = [
        { setting: "setting_one", value: "value1" },
        { setting: "setting_two", value: "value2" },
        { setting: "setting_three", value: "value3" },
      ];

      const result = controller.findSetting("setting_two");

      assert.deepEqual(
        result,
        { setting: "setting_two", value: "value2" },
        "should return the correct setting"
      );
    });

    test("findSetting returns undefined for non-existent setting", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      controller.settings = [{ setting: "setting_one", value: "value1" }];

      const result = controller.findSetting("nonexistent");

      assert.strictEqual(
        result,
        undefined,
        "should return undefined for non-existent setting"
      );
    });
  }
);
