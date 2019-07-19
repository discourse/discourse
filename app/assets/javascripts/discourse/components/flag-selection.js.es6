import { observes } from "ember-addons/ember-computed-decorators";

// Mostly hacks because `flag.hbs` didn't use `radio-button`
export default Ember.Component.extend({
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
    Ember.run.next(this, this._selectRadio);
  }
});
