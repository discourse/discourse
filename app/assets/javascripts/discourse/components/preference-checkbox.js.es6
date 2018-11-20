export default Em.Component.extend({
  classNames: ["controls"],

  label: function() {
    return I18n.t(this.get("labelKey"));
  }.property("labelKey"),

  change() {
    const warning = this.get("warning");

    if (warning && this.get("checked")) {
      this.sendAction("warning");
      return false;
    }

    return true;
  }
});
