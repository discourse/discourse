export default Ember.Component.extend({
  didInsertElement() {
    this._super();
    $("body").addClass("admin-interface");
  },

  willDestroyElement() {
    this._super();
    $("body").removeClass("admin-interface");
  }
});
