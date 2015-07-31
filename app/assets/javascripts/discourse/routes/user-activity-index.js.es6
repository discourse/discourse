import UserActivityStreamRoute from "discourse/routes/user-activity-stream";

export default UserActivityStreamRoute.extend({
  userActionType: undefined,

  actions: {
    didTransition() {
      this._super();
      this.controllerFor("user").set("indexStream", true);
      return true;
    }
  }

});
