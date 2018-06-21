export default Discourse.Route.extend({
  model() {
    return this.store.findAll("flagged-topic");
  },

  setupController(controller, model) {
    controller.set("flaggedTopics", model);
  }
});
