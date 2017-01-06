export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.index.title');
  },

  model(params) {
    return this.store.findAll('group', params);
  },

  setupController(controller, model) {
    controller.set('groups', model);
  }
});
