import { module, test } from "qunit";
import CategoryListControl from "discourse/components/setting-field/category-list";
import CompactListControl from "discourse/components/setting-field/compact-list";
import DurationControl from "discourse/components/setting-field/duration";
import GroupListControl from "discourse/components/setting-field/group-list";
import StringControl from "discourse/components/setting-field/string";
import {
  resolveSettingFieldType,
  settingFieldValidation,
} from "discourse/lib/setting-field-registry";

module("Unit | Lib | setting-field-registry", function () {
  module("resolveSettingFieldType", function () {
    test("resolves built-in types to their control", function (assert) {
      assert.strictEqual(
        resolveSettingFieldType({ type: "bool" }).type,
        "checkbox"
      );
      assert.strictEqual(
        resolveSettingFieldType({ type: "integer" }).type,
        "input-number"
      );
      assert.strictEqual(
        resolveSettingFieldType({ type: "enum" }).type,
        "select"
      );
    });

    test("falls back to the string control for unknown/missing types", function (assert) {
      assert.strictEqual(
        resolveSettingFieldType({ type: "not_a_real_type" }).renderer,
        StringControl
      );
      assert.strictEqual(resolveSettingFieldType({}).renderer, StringControl);
    });

    test("matches a registered subtype before the base type", function (assert) {
      assert.strictEqual(
        resolveSettingFieldType({ type: "integer", subtype: "duration" })
          .renderer,
        DurationControl,
        "subtype wins over type"
      );
      assert.strictEqual(
        resolveSettingFieldType({ type: "integer", subtype: "nope" }).type,
        "input-number",
        "an unregistered subtype falls through to the type"
      );
    });

    test("collapses list + list_type into the matching list control", function (assert) {
      assert.strictEqual(
        resolveSettingFieldType({ type: "list", list_type: "group" }).renderer,
        GroupListControl
      );
      assert.strictEqual(
        resolveSettingFieldType({ type: "list", list_type: "category" })
          .renderer,
        CategoryListControl
      );
      assert.strictEqual(
        resolveSettingFieldType({ type: "list", list_type: "compact" })
          .renderer,
        CompactListControl
      );
    });

    test("resolves a first-class list type without a list_type discriminator", function (assert) {
      assert.strictEqual(
        resolveSettingFieldType({ type: "category_list" }).renderer,
        CategoryListControl
      );
    });
  });

  module("settingFieldValidation", function () {
    test("integer validates as a number", function (assert) {
      assert.strictEqual(settingFieldValidation({ type: "integer" }), "number");
      assert.strictEqual(
        settingFieldValidation({ type: "integer", min: 0, max: 100 }),
        "number",
        "range is enforced by native min/max + the server, not a FormKit between rule"
      );
    });

    test("non-integer without constraints has no validation", function (assert) {
      assert.strictEqual(settingFieldValidation({ type: "string" }), undefined);
    });

    test("required is prepended", function (assert) {
      assert.strictEqual(
        settingFieldValidation({ type: "string", required: true }),
        "required"
      );
      assert.strictEqual(
        settingFieldValidation({
          type: "integer",
          required: true,
        }),
        "required|number"
      );
    });
  });
});
