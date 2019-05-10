export default Discourse.Route.extend({
  model() {
    return this.store.find("reviewable-settings");
  },

  setupController(controller, model) {
    controller.set("settings", model);
  }
});
