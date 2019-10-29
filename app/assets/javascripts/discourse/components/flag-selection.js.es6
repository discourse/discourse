import { next } from "@ember/runloop";
import Component from "@ember/component";
import { observes } from "ember-addons/ember-computed-decorators";

// Mostly hacks because `flag.hbs` didn't use `radio-button`
export default Component.extend({
  _selectRadio() {
    this.element.querySelector("input[type='radio']").checked = false;

    const nameKey = this.nameKey;
    if (!nameKey) {
      return;
    }

    this.element.querySelector("#radio_" + nameKey).checked = "true";
  },

  @observes("nameKey")
  selectedChanged() {
    next(this, this._selectRadio);
  }
});
