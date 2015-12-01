export default Discourse.Route.extend({

  model() {
    return this.modelFor("group").findPosts({type: 'mentions'});
  },

  setupController(controller, model) {
    controller.set("model", model);
    this.controllerFor("group").set("showing", "mentions");
  }
});
