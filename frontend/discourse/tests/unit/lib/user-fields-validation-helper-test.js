import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import UserFieldsValidationHelper from "discourse/lib/user-fields-validation-helper";
import { i18n } from "discourse-i18n";

module("Unit | Lib | user-fields-validation-helper", function (hooks) {
  setupTest(hooks);

  function requiredNumberField() {
    const helper = new UserFieldsValidationHelper({
      getUserFields: () => [
        { id: 1, name: "Score", field_type: "number", required: true },
      ],
      getAccountPassword: () => null,
    });
    return helper.userFields[0];
  }

  test("accepts 0 for a required number field", function (assert) {
    const userField = requiredNumberField();
    userField.value = 0;

    assert.true(userField.validation.ok, "0 counts as a value");
  });

  test("rejects an empty required number field", function (assert) {
    const userField = requiredNumberField();
    userField.value = "";

    assert.strictEqual(
      userField.validation.reason,
      i18n("user_fields.required", { name: "Score" }),
      "asks for a value"
    );
  });
});
