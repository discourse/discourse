import { observes } from "ember-addons/ember-computed-decorators";

// Mostly hacks because `flag.hbs` didn't use `radio-button`
export default Ember.Component.extend({
  _selectRadio() {
    this.$("input[type='radio']").prop("checked", false);

    const nameKey = this.get("nameKey");
    if (!nameKey) {
      return;
    }

    this.$("#radio_" + nameKey).prop("checked", "true");
  },

  @observes("nameKey")
  selectedChanged() {
    Ember.run.next(this, this._selectRadio);
  }
});
