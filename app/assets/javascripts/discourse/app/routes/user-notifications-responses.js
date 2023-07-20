import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import I18n from "I18n";

export default UserActivityStreamRoute.extend({
  userActionType: UserAction.TYPES["replies"],

  titleToken() {
    return I18n.t("user_action_groups.6");
  },
});
