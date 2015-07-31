export default Discourse.Route.extend({
  actions: {
    didTransition() { return true; }
  },

  model() {
    return this.modelFor("group").findPosts();
  },

  setupController(controller, model) {
    controller.set("model", model);
    this.controllerFor("group").set("showing", "index");
  }
});
