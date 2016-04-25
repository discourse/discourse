export default Discourse.Route.extend({
  model() {
    return this.store.findAll('tag');
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
