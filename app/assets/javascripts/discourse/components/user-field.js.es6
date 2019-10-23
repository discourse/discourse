import Component from "@ember/component";
import { fmt } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNameBindings: [":user-field", "field.field_type", "customFieldClass"],
  layoutName: fmt("field.field_type", "components/user-fields/%@"),

  @computed
  noneLabel() {
    return "user_fields.none";
  },

  @computed("field.name")
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
