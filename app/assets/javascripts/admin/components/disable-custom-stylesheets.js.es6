export default Ember.Component.extend({
  willInsertElement() {
    this._super();
    if (this.session.get("disableCustomCSS")) {
      $("link.custom-css").attr("rel", "");
      this.session.set("disableCustomCSS", false);
    }
  },

  willDestroyElement() {
    this._super();
    $("link.custom-css").attr("rel", "stylesheet");
  }
});
