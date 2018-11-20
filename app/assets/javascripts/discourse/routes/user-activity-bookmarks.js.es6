import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import UserAction from "discourse/models/user-action";

export default UserActivityStreamRoute.extend({
  userActionType: UserAction.TYPES["bookmarks"],
  noContentHelpKey: "user_activity.no_bookmarks",

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
