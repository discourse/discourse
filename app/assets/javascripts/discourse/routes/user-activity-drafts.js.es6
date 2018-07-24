export default Discourse.Route.extend({
  model() {
    return this.modelFor("user").get("userDraftsStream");
  },

  afterModel() {
    return this.modelFor("user")
      .get("userDraftsStream")
      .load();
  },

  renderTemplate() {
    this.render("user_stream");
  },

  setupController(controller, model) {
    controller.set("model", model);
  },

  actions: {
    didTransition() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    },

    refreshDrafts() {
      this.refresh();
    }
  }
});
