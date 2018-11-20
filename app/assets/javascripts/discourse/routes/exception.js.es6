export default Discourse.Route.extend({
  serialize() {
    return "";
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
