import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import I18n from "discourse-i18n";

export default class UserNotificationsLikesReceived extends UserActivityStreamRoute {
  userActionType = UserAction.TYPES["likes_received"];

  titleToken() {
    return I18n.t("user_action_groups.1");
  }
}
