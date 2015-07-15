export default Discourse.Route.extend({
  model() {
    return Discourse.Permalink.findAll();
  },

  setupController(controller, model) {
    controller.set('model', model);
  }
});
