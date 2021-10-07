import DiscourseRoute from "discourse/routes/discourse";
import UserBadge from "discourse/models/user-badge";
import ViewingActionType from "discourse/mixins/viewing-action-type";
import { action } from "@ember/object";

export default DiscourseRoute.extend(ViewingActionType, {
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

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  },
});
