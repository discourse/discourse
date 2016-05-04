export default Discourse.Route.extend({
  model() {
    return this.store.findAll('tag');
  },

  titleToken() {
    return I18n.t("tagging.tags");
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
