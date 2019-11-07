import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { fmt } from "discourse/lib/computed";

export default Component.extend({
  classNameBindings: [":user-field", "field.field_type", "customFieldClass"],
  layoutName: fmt("field.field_type", "components/user-fields/%@"),

  @discourseComputed
  noneLabel() {
    return "user_fields.none";
  },

  @discourseComputed("field.name")
  customFieldClass(fieldName) {
    if (fieldName) {
      fieldName = fieldName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return fieldName && `user-field-${fieldName}`;
    }
  }
});
