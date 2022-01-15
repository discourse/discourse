import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { action } from "@ember/object";

export default UserActivityStreamRoute.extend({
  userActionType: UserAction.TYPES["likes_given"],
  emptyStateOthers: I18n.t("user_activity.no_likes_others"),

  emptyState() {
    const title = I18n.t("user_activity.no_likes_title");
    const body = I18n.t("user_activity.no_likes_body", {
      heartIcon: iconHTML("heart"),
    }).htmlSafe();

    return { title, body };
  },

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  },
});
