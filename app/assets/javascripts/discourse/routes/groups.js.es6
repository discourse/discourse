export default Discourse.Route.extend({
  queryParams: {
    order: { refreshModel: true, replace: true },
    asc: { refreshModel: true, replace: true },
    filter: { refreshModel: true }
  },

  refreshQueryWithoutTransition: true,

  titleToken() {
    return I18n.t('groups.index.title');
  },

  model(params) {
    return this.store.findAll('group', params);
  },

  setupController(controller, model) {
    controller.set('model', model);
  }
});
