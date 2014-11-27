import UserActivityStreamRoute from "discourse/routes/user-activity-stream";

export default UserActivityStreamRoute.extend({
  userActionType: Discourse.UserAction.TYPES["likes_received"]
});
