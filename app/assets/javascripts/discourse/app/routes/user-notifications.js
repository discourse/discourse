import DiscourseRoute from "discourse/routes/discourse";
import ViewingActionType from "discourse/mixins/viewing-action-type";
import { action } from "@ember/object";
import I18n from "I18n";

export default DiscourseRoute.extend(ViewingActionType, {
  controllerName: "user-notifications",
  queryParams: { filter: { refreshModel: true } },

  @action
  didTransition() {
    this.controllerFor("user-notifications")._showFooter();
    return true;
  },

  model(params) {
    const username = this.modelFor("user").get("username");

    if (
      this.get("currentUser.username") === username ||
      this.get("currentUser.admin")
    ) {
      return this.store.find("notification", {
        username,
        filter: params.filter,
      });
    }
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("user", this.modelFor("user"));
    this.viewingActionType(-1);
  },

  titleToken() {
    return I18n.t("user.notifications");
  },
});
