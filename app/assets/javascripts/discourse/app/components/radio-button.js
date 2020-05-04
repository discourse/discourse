import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  tagName: "input",
  type: "radio",
  attributeBindings: [
    "name",
    "type",
    "value",
    "checked:checked",
    "disabled:disabled"
  ],

  click() {
    const value = $(this.element).val();

    if (this.onChange) {
      this.onChange(value);
    } else {
      if (this.selection === value) {
        this.set("selection", undefined);
      }
      this.set("selection", value);
    }
  },

  @discourseComputed("value", "selection")
  checked(value, selection) {
    return value === selection;
  }
});
