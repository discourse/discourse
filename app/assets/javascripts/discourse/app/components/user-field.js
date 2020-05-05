import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { fmt } from "discourse/lib/computed";
import { action } from "@ember/object";

export default Component.extend({
  classNameBindings: [":user-field", "field.field_type", "customFieldClass"],
  layoutName: fmt("field.field_type", "components/user-fields/%@"),

  didInsertElement() {
    this.field.component = this;
  },

  @action
  focus() {
    if (this.element.querySelector("input")) {
      this.element.querySelector("input").focus();
    } else {
      const header = this.element.querySelector(
        ".user-field.dropdown .select-kit-header"
      );

      if (header.scrollIntoView) {
        header.scrollIntoView();
      }

      header.click();
    }
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
  }
});
