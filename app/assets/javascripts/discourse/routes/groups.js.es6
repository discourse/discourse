export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.index');
  },

  model(params) {
    return this.store.findAll('group', params);
  },

  setupController(controller, model) {
    controller.set('groups', model);
  }
});
