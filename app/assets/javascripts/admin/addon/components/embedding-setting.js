import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { dasherize } from "@ember/string";

export default Component.extend({
  tagName: "",

  @discourseComputed("field")
  inputId(field) {
    return dasherize(field);
  },

  @discourseComputed("field")
  translationKey(field) {
    return `admin.embedding.${field}`;
  },

  @discourseComputed("type")
  isCheckbox(type) {
    return type === "checkbox";
  },

  @discourseComputed("value")
  checked: {
    get(value) {
      return !!value;
    },
    set(value) {
      this.set("value", value);
      return value;
    },
  },
});
