import Component from "@ember/component";
import { next } from "@ember/runloop";
import { observes } from "discourse-common/utils/decorators";

// Mostly hacks because `flag.hbs` didn't use `radio-button`
export default Component.extend({
  _selectRadio() {
    this.element.querySelector("input[type='radio']").checked = false;

    const nameKey = this.nameKey;
    if (!nameKey) {
      return;
    }

    const selector = this.element.querySelector("#radio_" + nameKey);
    if (selector) {
      selector.checked = "true";
    }
  },

  @observes("nameKey")
  selectedChanged() {
    next(this, this._selectRadio);
  },
});
