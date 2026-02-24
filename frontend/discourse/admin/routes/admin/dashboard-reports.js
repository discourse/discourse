import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminDashboardReportsRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    if (this.siteSettings.reporting_improvements) {
      this.router.replaceWith("adminReports");
    }
  }

  model() {
    if (!this.siteSettings.reporting_improvements) {
      return ajax("/admin/reports");
    }
  }

  setupController(controller, model) {
    if (!this.siteSettings.reporting_improvements) {
      controller.setProperties({ model: model.reports, filter: null });
    }
  }
}
