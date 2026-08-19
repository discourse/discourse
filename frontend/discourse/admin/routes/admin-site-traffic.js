import { action } from "@ember/object";
import { service } from "@ember/service";
import { loadSiteTraffic } from "discourse/admin/lib/site-traffic-model";
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

  async model(params) {
    try {
      return { traffic: await loadSiteTraffic(params), fetchError: null };
    } catch (error) {
      return {
        traffic: null,
        fetchError:
          error.jqXHR?.responseJSON?.error_type === "traffic_query_timeout"
            ? "timeout"
            : "unexpected",
      };
    }
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
