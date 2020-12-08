import UserAction from "discourse/models/user-action";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";

export default UserActivityStreamRoute.extend({
  userActionType: UserAction.TYPES["replies"],
});
