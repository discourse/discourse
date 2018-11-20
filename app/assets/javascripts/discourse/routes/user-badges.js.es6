import ViewingActionType from "discourse/mixins/viewing-action-type";
import UserBadge from "discourse/models/user-badge";

export default Discourse.Route.extend(ViewingActionType, {
  model() {
    return UserBadge.findByUsername(
      this.modelFor("user").get("username_lower"),
      { grouped: true }
    );
  },

  setupController(controller, model) {
    this.viewingActionType(-1);
    controller.set("model", model);
  },

  renderTemplate() {
    this.render("user/badges", { into: "user" });
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
