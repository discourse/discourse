import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import I18n from "I18n";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import getURL from "discourse-common/lib/get-url";

export default UserActivityStreamRoute.extend({
  userActionType: UserAction.TYPES["posts"],

  emptyState() {
    const user = this.modelFor("user");

    let title, body;
    if (this.isCurrentUser(user)) {
      title = I18n.t("user_activity.no_replies_title");
      body = htmlSafe(
        I18n.t("user_activity.no_replies_body", {
          searchUrl: getURL("/search"),
        })
      );
    } else {
      title = I18n.t("user_activity.no_replies_title_others", {
        username: user.username,
      });
      body = "";
    }

    return { title, body };
  },

  titleToken() {
    return I18n.t("user_action_groups.5");
  },

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  },
});
