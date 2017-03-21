export default Discourse.Route.extend({
  model() {
    return this.modelFor("user").summary();
  },

  actions: {
    didTransition() {
      this.controllerFor("user").set("indexStream", true);
    }
  }
});
