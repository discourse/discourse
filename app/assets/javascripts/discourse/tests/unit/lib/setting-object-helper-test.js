import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SettingObjectHelper from "admin/lib/setting-object-helper";

module("Unit | Lib | setting-object-helper", function (hooks) {
  setupTest(hooks);

  test("flat array", function (assert) {
    const settingObj = EmberObject.create({
      valid_values: ["foo", "bar"],
    });

    const helper = new SettingObjectHelper(settingObj);

    assert.strictEqual(helper.computedValueProperty, null);
    assert.strictEqual(helper.computedNameProperty, null);
  });

  test("object", function (assert) {
    const settingObj = EmberObject.create({
      valid_values: [{ value: "foo", name: "bar" }],
    });

    const helper = new SettingObjectHelper(settingObj);

    assert.strictEqual(helper.computedValueProperty, "value");
    assert.strictEqual(helper.computedNameProperty, "name");
  });

  test("no values", function (assert) {
    const settingObj = EmberObject.create({
      valid_values: [],
    });

    const helper = new SettingObjectHelper(settingObj);

    assert.strictEqual(helper.computedValueProperty, null);
    assert.strictEqual(helper.computedNameProperty, null);
  });

  test("value/name properties defined", function (assert) {
    const settingObj = EmberObject.create({
      valueProperty: "foo",
      nameProperty: "bar",
      valid_values: [],
    });

    const helper = new SettingObjectHelper(settingObj);

    assert.strictEqual(helper.computedValueProperty, "foo");
    assert.strictEqual(helper.computedNameProperty, "bar");
  });
});
