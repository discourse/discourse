import { scrollTop } from "discourse/lib/scroll-top";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminDashboardRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.dashboard.title");
  }

  activate() {
    scrollTop();
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (controller.showRedesign) {
      controller.fetchSections();
    } else {
      controller.fetchProblems();
      controller.fetchDashboard();
    }
  }
}
