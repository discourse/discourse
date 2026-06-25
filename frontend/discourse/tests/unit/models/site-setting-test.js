import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";

module("Unit | Model | site-setting", function (hooks) {
  setupTest(hooks);

  test("definition projects the setting onto the field definition contract", function (assert) {
    const setting = SiteSetting.create({
      setting: "title",
      humanized_name: "Title",
      description: "The name of the site",
      type: "string",
      list_type: null,
      min: 1,
      max: 100,
      choices: ["a", "b"],
      valid_values: ["a", "b"],
    });

    assert.deepEqual(setting.definition, {
      key: "title",
      label: "Title",
      description: "The name of the site",
      type: "string",
      list_type: null,
      min: 1,
      max: 100,
      choices: ["a", "b"],
      valid_values: ["a", "b"],
    });
  });
});
