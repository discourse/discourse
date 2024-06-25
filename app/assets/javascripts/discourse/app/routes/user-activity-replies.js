import { htmlSafe } from "@ember/template";
import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class UserActivityReplies extends UserActivityStreamRoute {
  userActionType = UserAction.TYPES["posts"];

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
  }

  titleToken() {
    return I18n.t("user_action_groups.5");
  }
}
