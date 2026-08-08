import { scrollTop } from "discourse/lib/scroll-top";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminSiteTrafficRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.site_traffic_explorer.title");
  }

  activate() {
    scrollTop();
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (controller.range) {
      controller.fetchTraffic();
    } else {
      controller.setPeriod(controller.defaultPeriod);
    }
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.resetState();
    }
  }
}
