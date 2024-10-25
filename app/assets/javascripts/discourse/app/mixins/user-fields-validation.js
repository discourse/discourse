import EmberObject, { computed } from "@ember/object";
import { on } from "@ember/object/evented";
import Mixin from "@ember/object/mixin";
import { isEmpty } from "@ember/utils";
import I18n from "discourse-i18n";

const addCustomUserFieldValidationCallbacks = [];
export function addCustomUserFieldValidationCallback(callback) {
  addCustomUserFieldValidationCallbacks.push(callback);
}

export default Mixin.create({
  _createUserFields: on("init", function () {
    if (!this.site) {
      return;
    }

    let userFields = this.site.get("user_fields");
    if (userFields) {
      userFields = userFields
        .filter((uf) => uf.requirement !== "for_existing_users")
        .sortBy("position")
        .map((f) => EmberObject.create({ value: null, field: f }));
    }
    this.set("userFields", userFields);
  }),

  userFieldsValidation: computed("userFields.@each.value", function () {
    if (!this.userFields) {
      return EmberObject.create({ ok: true });
    }

    this.userFields.forEach((userField) => {
      let validation = EmberObject.create({ ok: true });

      if (
        userField.field.required &&
        (!userField.value || isEmpty(userField.value))
      ) {
        validation = EmberObject.create({
          failed: true,
          reason: I18n.t("user_fields.required", {
            name: userField.field.name,
          }),
          element: userField.field.element,
        });
      } else if (
        this.accountPassword &&
        userField.field.field_type === "text" &&
        userField.value &&
        userField.value
          .toLowerCase()
          .includes(this.accountPassword.toLowerCase())
      ) {
        validation = EmberObject.create({
          failed: true,
          reason: I18n.t("user_fields.same_as_password"),
          element: userField.field.element,
        });
      }

      addCustomUserFieldValidationCallbacks.map((callback) => {
        const customUserFieldValidationObject = callback(userField);
        if (customUserFieldValidationObject) {
          validation = customUserFieldValidationObject;
        }
      });

      userField.set("validation", validation);
    });

    const invalidUserField = this.userFields.find((f) => f.validation.failed);
    if (invalidUserField) {
      return invalidUserField.validation;
    }

    return EmberObject.create({ ok: true });
  }),
});
