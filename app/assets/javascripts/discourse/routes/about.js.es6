export default Discourse.Route.extend({
  model() {
    return Discourse.ajax("/about.json").then(result => result.about);
  },

  titleToken() {
    return I18n.t('about.simple_title');
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
