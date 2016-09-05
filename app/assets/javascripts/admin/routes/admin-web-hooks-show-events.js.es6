export default Discourse.Route.extend({
  model(params) {
    return this.store.findAll('web-hook-event', Ember.get(params, 'web_hook_id'));
  },

  setupController(controller, model) {
    controller.set('model', model);
  },

  renderTemplate() {
    this.render('admin/templates/web-hooks-show-events', { into: 'admin' });
  }
});
