import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ViewingActionType, {
  queryParams: {
    acting_username: { refreshModel: true }
  },

  model() {
    return this.modelFor("user").get("stream");
  },

  afterModel(model, transition) {
    return model.filterBy(
      this.get("userActionType"),
      this.get("noContentHelpKey") || "user_activity.no_default",
      transition.queryParams.acting_username
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
