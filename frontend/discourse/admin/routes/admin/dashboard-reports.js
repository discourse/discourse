import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminDashboardReportsRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminReports");
  }
}
