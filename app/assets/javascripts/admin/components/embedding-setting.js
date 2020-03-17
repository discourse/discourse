import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  classNames: ["embed-setting"],

  @discourseComputed("field")
  inputId(field) {
    return field.dasherize();
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
    }
  }
});
