import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ViewingActionType, {
  actions: {
    didTransition() {
      this.controllerFor("user-notifications")._showFooter();
      return true;
    }
  },

  model() {
    return this.store.find("notification", { username: this.modelFor("user").get("username") });
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("user", this.modelFor("user"));
    this.viewingActionType(-1);
  }
});
