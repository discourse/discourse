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
      const anyEmpty = userFields.any(uf => {
        const val = uf.get("value");
        return !val || isEmpty(val);
      });
      if (anyEmpty) {
        return EmberObject.create({ failed: true });
      }
    }
    return EmberObject.create({ ok: true });
  }
});
