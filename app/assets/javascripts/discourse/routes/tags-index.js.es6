export default Discourse.Route.extend({
  model() {
    return this.store.findAll('tag');
  },

  titleToken() {
    return I18n.t("tagging.tags");
  },

  setupController(controller, model) {
    this.controllerFor('tags.index').setProperties({
      model,
      sortProperties: this.siteSettings.tags_sort_alphabetically ? ['id'] : ['count:desc', 'id']
    });
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
