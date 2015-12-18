import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import UserAction from "discourse/models/user-action";

export default UserActivityStreamRoute.extend({
  userActionType: UserAction.TYPES["mentions"]
});
