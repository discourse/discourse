export default Ember.Route.extend({
  queryParams: {
    q: { replace: true }
  },

  model(params) {
    return this.store.find('site-text', { q: params.q });
  },

  setupController(controller, model) {
    controller.set('siteTexts', model);
  }
});
