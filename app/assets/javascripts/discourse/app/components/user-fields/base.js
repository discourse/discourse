import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [":user-field", "field.field_type", "customFieldClass"],

  didInsertElement() {
    this._super(...arguments);

    let element = this.element.querySelector(
      ".user-field.dropdown .select-kit-header"
    );
    element = element || this.element.querySelector("input");
    this.field.element = element;
  },

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
  },
});
