import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";

module("Unit | Model | site-setting", function (hooks) {
  setupTest(hooks);

  test("definition projects the setting onto the field definition contract", function (assert) {
    const setting = SiteSetting.create({
      setting: "title",
      humanized_name: "Title",
      description: "The <strong>name</strong> of the site",
      type: "string",
      list_type: null,
      min: 1,
      max: 100,
      choices: ["a", "b"],
      valid_values: [
        { name: "category_scope.all", value: "a" },
        { name: "category_scope.public", value: "b" },
      ],
      translate_names: true,
    });

    const definition = setting.definition;

    assert.strictEqual(definition.key, "title");
    assert.strictEqual(definition.label, "Title");
    assert.strictEqual(
      definition.description.toString(),
      "The <strong>name</strong> of the site"
    );
    assert.strictEqual(definition.type, "string");
    assert.strictEqual(definition.list_type, null);
    assert.strictEqual(definition.min, 1);
    assert.strictEqual(definition.max, 100);
    assert.deepEqual(definition.choices, ["a", "b"]);
    assert.strictEqual(definition.valid_values.length, 2);
    assert.strictEqual(
      definition.valid_values[0].name,
      "All public and private categories"
    );
    assert.strictEqual(definition.valid_values[0].value, "a");
    assert.strictEqual(definition.valid_values[1].name, "Public categories");
    assert.strictEqual(definition.valid_values[1].value, "b");
  });
});
