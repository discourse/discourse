export default Discourse.Route.extend({
  model() {
    let userDraftsStream = this.modelFor("user").get("userDraftsStream");
    return userDraftsStream.load(this.site).then(() => userDraftsStream);
  },

  renderTemplate() {
    this.render("user_stream");
  },

  setupController(controller, model) {
    controller.set("model", model);
    this.appEvents.on("draft:destroyed", this, this.refresh);
  },

  actions: {
    didTransition() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    }
  }
});
