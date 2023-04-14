import DiscourseRoute from "discourse/routes/discourse";

export default class AdminReportsIndexRoute extends DiscourseRoute {
  beforeModel() {
    this.transitionTo("admin.dashboardReports");
  }
}
