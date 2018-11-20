export default Ember.Route.extend({
  beforeModel() {
    const appModel = this.modelFor("application");
    this.replaceWith("step", appModel.start);
  }
});
