export default Discourse.Route.extend({

  model() {
    return this.modelFor("group").findPosts({type: 'messages'});
  },

  setupController(controller, model) {
    controller.set("model", model);
    this.controllerFor("group").set("showing", "messages");
  }
});
