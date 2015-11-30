export default Ember.Route.extend({
  queryParams: {
    q: { replace: true },
    overridden: { replace: true }
  },

  model(params) {
    return this.store.find('site-text', Ember.getProperties(params, 'q', 'overridden'));
  },

  setupController(controller, model) {
    controller.set('siteTexts', model);
  }
});
