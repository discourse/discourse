import { service } from "@ember/service";
import {
  SITE_TRAFFIC_SAFE_FILTERS,
  validSiteTrafficSafeFilter,
} from "discourse/admin/lib/site-traffic-filters";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const LEGACY_FILTER_KEYS = [...SITE_TRAFFIC_SAFE_FILTERS, "url", "ip"];

export default class AdminDashboardTrafficRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel() {
    if (!this.currentUser?.admin) {
      return this.router.replaceWith("/404");
    }
  }

  setupController(controller, model, transition) {
    super.setupController(...arguments);
    const { start_date: startDate, end_date: endDate } =
      transition.to.queryParams;

    if (moment(startDate, "YYYY-MM-DD", true).isValid()) {
      controller.start_date = startDate;
    }
    if (moment(endDate, "YYYY-MM-DD", true).isValid()) {
      controller.end_date = endDate;
    }

    this.#migrateLegacyFilters(controller);
    controller.ensureDefaultRange();
  }

  #migrateLegacyFilters(controller) {
    const legacyFilters = new URLSearchParams(window.location.hash.slice(1));
    if (!LEGACY_FILTER_KEYS.some((key) => legacyFilters.has(key))) {
      return;
    }

    const queryParams = new URLSearchParams(window.location.search);
    const safeFilters = Object.fromEntries(
      SITE_TRAFFIC_SAFE_FILTERS.map((key) => {
        const queryValue = queryParams.get(key);
        const legacyValue = legacyFilters.get(key);
        let value = null;

        if (validSiteTrafficSafeFilter(key, queryValue)) {
          value = queryValue;
        } else if (validSiteTrafficSafeFilter(key, legacyValue)) {
          value = legacyValue;
        }

        if (value) {
          queryParams.set(key, value);
        }

        return [key, value];
      })
    );

    controller.setSafeFilters(safeFilters);

    const query = queryParams.toString();
    window.history.replaceState(
      window.history.state,
      "",
      `${window.location.pathname}${query ? `?${query}` : ""}`
    );
  }

  titleToken() {
    return i18n("admin.dashboard.site_traffic.details.title");
  }
}
