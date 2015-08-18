export default Ember.Route.extend({
  model() {
    return this.store.find('embedding');
  },

  setupController(controller, model) {
    controller.set('embedding', model);
  }
});
