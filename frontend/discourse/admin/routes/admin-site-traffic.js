import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminSiteTrafficRoute extends DiscourseRoute {
  @service loadingSlider;

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

  model(params) {
    return this.controllerFor("admin-site-traffic").loadTraffic(params);
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.applyTrafficModel(model);
  }

  @action
  loading(transition) {
    const showFallbackSpinner =
      this.controllerFor("admin-site-traffic").traffic === null;
    this.loadingSlider.transitionStarted({ showFallbackSpinner });
    transition.finally(this.loadingSlider.transitionEnded);
    return false;
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.resetState();
    }
  }
}
