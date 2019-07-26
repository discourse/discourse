export default Ember.Route.extend({
  model() {
    return this.store.find("email-style");
  },

  redirect() {
    this.transitionTo("adminCustomizeEmailStyle.edit", "html");
  }
});
