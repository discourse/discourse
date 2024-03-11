import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminReportsIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.transitionTo("admin.dashboardReports");
  }
}
