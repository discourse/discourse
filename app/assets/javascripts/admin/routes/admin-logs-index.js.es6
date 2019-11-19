import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  redirect: function() {
    this.transitionTo("adminLogs.staffActionLogs");
  }
});
