export default Discourse.Route.extend({
  showFooter: true,

  model() {
    return this.modelFor("user").summary();
  },

  actions: {
    didTransition() {
      this.controllerFor("user").set("indexStream", true);
    }
  }
});
