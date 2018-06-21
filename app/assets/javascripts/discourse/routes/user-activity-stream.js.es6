import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ViewingActionType, {
  model() {
    return this.modelFor("user").get("stream");
  },

  afterModel() {
    return this.modelFor("user")
      .get("stream")
      .filterBy(
        this.get("userActionType"),
        this.get("noContentHelpKey") || "user_activity.no_default"
      );
  },

  renderTemplate() {
    this.render("user_stream");
  },

  setupController(controller, model) {
    controller.set("model", model);
    this.viewingActionType(this.get("userActionType"));
  },

  actions: {
    didTransition() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    }
  }
});
