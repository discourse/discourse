import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminSiteTrafficRoute extends DiscourseRoute {
  queryParams = {
    range: { refreshModel: false },
    start_date: { refreshModel: false },
    end_date: { refreshModel: false },
    traffic_type: { refreshModel: false },
    top_url: { refreshModel: false },
    entry_url: { refreshModel: false },
    referrer: { refreshModel: false },
    country: { refreshModel: false },
    network: { refreshModel: false },
    browser: { refreshModel: false },
    ip: { refreshModel: false },
  };

  titleToken() {
    return i18n("admin.site_traffic_explorer.title");
  }

  model(params) {
    return params;
  }

  setupController(controller) {
    super.setupController(...arguments);
    this.#scheduleFetch(controller);
  }

  @action
  queryParamsDidChange() {
    this.#scheduleFetch(this.controllerFor("admin-site-traffic"));
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.resetState();
    }
  }

  #scheduleFetch(controller) {
    scheduleOnce("actions", controller, controller.fetchTraffic);
  }
}
