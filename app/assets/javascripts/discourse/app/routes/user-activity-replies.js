import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";

export default UserActivityStreamRoute.extend({
  userActionType: UserAction.TYPES["posts"],
  noContentHelpKey: "user_activity.no_replies",

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    },
  },
});
