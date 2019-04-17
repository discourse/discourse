import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["controls"],

  @computed("labelKey")
  label(labelKey) {
    return I18n.t(labelKey);
  },

  change() {
    const warning = this.get("warning");

    if (warning && this.get("checked")) {
      this.warning();
      return false;
    }

    return true;
  }
});
