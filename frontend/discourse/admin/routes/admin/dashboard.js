import { service } from "@ember/service";
import { scrollTop } from "discourse/lib/scroll-top";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminDashboardRoute extends DiscourseRoute {
  @service siteSettings;

  titleToken() {
    return i18n("admin.config.dashboard.title");
  }

  activate() {
    const controller = this.controllerFor("admin.dashboard");

    if (this.siteSettings.dashboard_improvements) {
      controller.fetchSections();
    } else {
      controller.fetchProblems();
      controller.fetchDashboard();
    }

    scrollTop();
  }
}
