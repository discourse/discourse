export default Ember.Component.extend({
  classNames: ["controls"],

  label: function() {
    return I18n.t(this.get("labelKey"));
  }.property("labelKey"),

  change() {
    const warning = this.get("warning");

    if (warning && this.get("checked")) {
      this.warning();
      return false;
    }

    return true;
  }
});
