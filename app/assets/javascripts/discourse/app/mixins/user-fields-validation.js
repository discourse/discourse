import discourseComputed, { on } from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";
import I18n from "I18n";
import Mixin from "@ember/object/mixin";
import { isEmpty } from "@ember/utils";

export default Mixin.create({
  @on("init")
  _createUserFields() {
    if (!this.site) {
      return;
    }

    let userFields = this.site.get("user_fields");
    if (userFields) {
      userFields = userFields
        .sortBy("position")
        .map((f) => EmberObject.create({ value: null, field: f }));
    }
    this.set("userFields", userFields);
  },

  @discourseComputed("userFields.@each.value")
  userFieldsValidation() {
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

      userField.set("validation", validation);
    });

    const invalidUserField = this.userFields.find((f) => f.validation.failed);
    if (invalidUserField) {
      return invalidUserField.validation;
    }

    return EmberObject.create({ ok: true });
  },
});
