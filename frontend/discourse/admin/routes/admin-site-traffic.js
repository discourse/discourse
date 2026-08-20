import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminSiteTrafficRoute extends DiscourseRoute {
  queryParams = {
    range: { refreshModel: true },
    start_date: { refreshModel: true },
    end_date: { refreshModel: true },
    traffic_type: { refreshModel: true },
    top_url: { refreshModel: true },
    entry_url: { refreshModel: true },
    referrer: { refreshModel: true },
    country: { refreshModel: true },
    network: { refreshModel: true },
    browser: { refreshModel: true },
    ip: { refreshModel: true },
  };

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
