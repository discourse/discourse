export default Discourse.Route.extend({
  model() {
    return this.modelFor("group");
  },

  setupController(controller, model) {
    this.controllerFor("group").set("showing", "members");
    controller.set("model", model);
    model.findMembers();
  }
});
