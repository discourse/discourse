import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class AdminReportsIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.transitionTo("admin.dashboardReports");
  }
}
