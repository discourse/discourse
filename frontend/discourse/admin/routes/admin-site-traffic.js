import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminSiteTrafficRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.site_traffic_explorer.title");
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.fetchTraffic();
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.resetState();
    }
  }
}
