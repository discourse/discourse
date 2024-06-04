import { htmlSafe } from "@ember/template";
import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export default class UserActivityLikesGiven extends UserActivityStreamRoute {
  userActionType = UserAction.TYPES["likes_given"];

  emptyState() {
    const user = this.modelFor("user");

    const title = this.isCurrentUser(user)
      ? I18n.t("user_activity.no_likes_title")
      : I18n.t("user_activity.no_likes_title_others", {
          username: user.username,
        });
    const body = htmlSafe(
      I18n.t("user_activity.no_likes_body", {
        heartIcon: iconHTML("heart"),
      })
    );

    return { title, body };
  }

  titleToken() {
    return I18n.t("user_action_groups.1");
  }
}
