import { htmlSafe } from "@ember/template";
import getURL from "discourse/lib/get-url";
import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { i18n } from "discourse-i18n";

export default class UserActivityReplies extends UserActivityStreamRoute {
  userActionType = UserAction.TYPES["posts"];

  emptyState() {
    const user = this.modelFor("user");

    let title, body;
    if (this.isCurrentUser(user)) {
      title = i18n("user_activity.no_replies_title");
      body = htmlSafe(
        i18n("user_activity.no_replies_body", {
          searchUrl: getURL("/search"),
        })
      );
    } else {
      title = i18n("user_activity.no_replies_title_others", {
        username: user.username,
      });
      body = "";
    }

    return { title, body };
  }

  titleToken() {
    return i18n("user_action_groups.5");
  }
}
