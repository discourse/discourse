import { test, module } from "qunit";
import EmberObject from "@ember/object";
import Setting from "admin/mixins/setting-object";

module("mixin:setting-object");

test("flat array", (assert) => {
  const FooSetting = EmberObject.extend(Setting);

  const fooSettingInstance = FooSetting.create({
    valid_values: ["foo", "bar"],
  });

  assert.equal(fooSettingInstance.computedValueProperty, null);
  assert.equal(fooSettingInstance.computedNameProperty, null);
});

test("object", (assert) => {
  const FooSetting = EmberObject.extend(Setting);

  const fooSettingInstance = FooSetting.create({
    valid_values: [{ value: "foo", name: "bar" }],
  });

  assert.equal(fooSettingInstance.computedValueProperty, "value");
  assert.equal(fooSettingInstance.computedNameProperty, "name");
});

test("no values", (assert) => {
  const FooSetting = EmberObject.extend(Setting);

  const fooSettingInstance = FooSetting.create({
    valid_values: [],
  });

  assert.equal(fooSettingInstance.computedValueProperty, null);
  assert.equal(fooSettingInstance.computedNameProperty, null);
});

test("value/name properties defined", (assert) => {
  const FooSetting = EmberObject.extend(Setting);

  const fooSettingInstance = FooSetting.create({
    valueProperty: "foo",
    nameProperty: "bar",
    valid_values: [],
  });

  assert.equal(fooSettingInstance.computedValueProperty, "foo");
  assert.equal(fooSettingInstance.computedNameProperty, "bar");
});
