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

  // Validate required fields
  @discourseComputed("userFields.@each.value")
  userFieldsValidation() {
    let userFields = this.userFields;
    if (userFields) {
      userFields = userFields.filterBy("field.required");
    }
    if (!isEmpty(userFields)) {
      const emptyUserField = userFields.find((uf) => {
        const val = uf.get("value");
        return !val || isEmpty(val);
      });
      if (emptyUserField) {
        const userField = emptyUserField.field;
        return EmberObject.create({
          failed: true,
          message: I18n.t("user_fields.required", { name: userField.name }),
          element: userField.element,
        });
      }
    }
    return EmberObject.create({ ok: true });
  },
});
