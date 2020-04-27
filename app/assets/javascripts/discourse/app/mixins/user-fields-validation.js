import { isEmpty } from "@ember/utils";
import EmberObject from "@ember/object";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  @on("init")
  _createUserFields() {
    if (!this.site) {
      return;
    }

    let userFields = this.site.get("user_fields");
    if (userFields) {
      userFields = _.sortBy(userFields, "position").map(function(f) {
        return EmberObject.create({ value: null, field: f });
      });
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
      const emptyUserField = userFields.find(uf => {
        const val = uf.get("value");
        return !val || isEmpty(val);
      });
      if (emptyUserField) {
        return EmberObject.create({
          failed: true,
          userField: emptyUserField
        });
      }
    }
    return EmberObject.create({ ok: true });
  }
});
