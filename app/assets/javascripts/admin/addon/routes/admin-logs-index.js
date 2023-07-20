import DiscourseRoute from "discourse/routes/discourse";

export default class AdminLogsIndexRoute extends DiscourseRoute {
  redirect() {
    this.transitionTo("adminLogs.staffActionLogs");
  }
}
