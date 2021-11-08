import { module, test } from "qunit";
import EmberObject from "@ember/object";
import Setting from "admin/mixins/setting-object";

module("Unit | Mixin | setting-object", function () {
  test("flat array", function (assert) {
    const FooSetting = EmberObject.extend(Setting);

    const fooSettingInstance = FooSetting.create({
      valid_values: ["foo", "bar"],
    });

    assert.strictEqual(fooSettingInstance.computedValueProperty, null);
    assert.strictEqual(fooSettingInstance.computedNameProperty, null);
  });

  test("object", function (assert) {
    const FooSetting = EmberObject.extend(Setting);

    const fooSettingInstance = FooSetting.create({
      valid_values: [{ value: "foo", name: "bar" }],
    });

    assert.strictEqual(fooSettingInstance.computedValueProperty, "value");
    assert.strictEqual(fooSettingInstance.computedNameProperty, "name");
  });

  test("no values", function (assert) {
    const FooSetting = EmberObject.extend(Setting);

    const fooSettingInstance = FooSetting.create({
      valid_values: [],
    });

    assert.strictEqual(fooSettingInstance.computedValueProperty, null);
    assert.strictEqual(fooSettingInstance.computedNameProperty, null);
  });

  test("value/name properties defined", function (assert) {
    const FooSetting = EmberObject.extend(Setting);

    const fooSettingInstance = FooSetting.create({
      valueProperty: "foo",
      nameProperty: "bar",
      valid_values: [],
    });

    assert.strictEqual(fooSettingInstance.computedValueProperty, "foo");
    assert.strictEqual(fooSettingInstance.computedNameProperty, "bar");
  });
});
