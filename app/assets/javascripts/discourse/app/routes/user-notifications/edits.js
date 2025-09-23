import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { i18n } from "discourse-i18n";

export default class UserNotificationsEdits extends UserActivityStreamRoute {
  userActionType = UserAction.TYPES["edits"];

  titleToken() {
    return i18n("user_action_groups.11");
  }
}
