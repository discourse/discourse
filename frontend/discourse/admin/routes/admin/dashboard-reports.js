import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminDashboardReportsRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminReports");
  }
}
