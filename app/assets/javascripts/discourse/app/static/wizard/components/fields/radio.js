import Component from "@ember/component";
import { action, set } from "@ember/object";

export default Component.extend({
  init() {
    this._super(...arguments);
    this.set("field.value", this.field.value);

    this._setSelected();
  },

  @action
  changed(input) {
    this.set("field.value", input.target.value);
    this._resetSelected();
    this._setSelected();
  },

  _resetSelected() {
    for (let choice of this.field.choices) {
      set(choice, "selected", false);
    }
  },

  _setSelected() {
    for (let choice of this.field.choices) {
      if (this.field.value === choice.id) {
        set(choice, "selected", true);
      }
    }
  },
});
