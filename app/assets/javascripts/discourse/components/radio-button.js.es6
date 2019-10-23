import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

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
    if (this.selection === value) {
      this.set("selection", undefined);
    }
    this.set("selection", value);
  },

  @computed("value", "selection")
  checked(value, selection) {
    return value === selection;
  }
});
