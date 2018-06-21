export default Ember.Route.extend({
  model() {
    return this.store.findAll("email-template");
  },

  setupController(controller, model) {
    controller.set("emailTemplates", model);
  }
});
