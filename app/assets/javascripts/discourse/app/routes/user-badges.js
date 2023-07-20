import DiscourseRoute from "discourse/routes/discourse";
import UserBadge from "discourse/models/user-badge";
import ViewingActionType from "discourse/mixins/viewing-action-type";
import { action } from "@ember/object";
import I18n from "I18n";

export default DiscourseRoute.extend(ViewingActionType, {
  templateName: "user/badges",

  model() {
    return UserBadge.findByUsername(
      this.modelFor("user").get("username_lower"),
      { grouped: true }
    );
  },

  setupController() {
    this._super(...arguments);
    this.viewingActionType(-1);
  },

  titleToken() {
    return I18n.t("badges.title");
  },

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  },
});
