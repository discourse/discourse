import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const FILTER_QUERY_PARAMS = {
  normalized_url: "url",
  normalized_referrer: "source",
  country_code: "country",
  asn: "network",
  ip_address: "ip",
  browser: "browser",
};

export default class AdminBrowserTrafficRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  queryParams = {
    start_date: { refreshModel: true },
    end_date: { refreshModel: true },
    url: { refreshModel: false },
    source: { refreshModel: false },
    country: { refreshModel: false },
    network: { refreshModel: false },
    ip: { refreshModel: false },
    browser: { refreshModel: false },
  };

  beforeModel() {
    if (
      !this.currentUser.admin ||
      !this.siteSettings.enable_browser_traffic_explorer
    ) {
      return this.router.transitionTo("admin.dashboard.general");
    }
  }

  async model(params) {
    const startDate =
      params.start_date || moment().subtract(29, "days").format("YYYY-MM-DD");
    const endDate = params.end_date || moment().format("YYYY-MM-DD");
    const filters = this.filtersFromParams(params);

    try {
      const result = await ajax("/admin/browser-traffic/data.json", {
        data: {
          start_date: startDate,
          end_date: endDate,
          ...this.filterParams(filters),
        },
      });
      return { startDate, endDate, filters, result };
    } catch (error) {
      return {
        startDate,
        endDate,
        filters,
        errorType: error.jqXHR?.responseJSON?.error_type || "unknown",
      };
    }
  }

  filtersFromParams(params) {
    const filters = Object.fromEntries(
      Object.entries({
        normalized_url: params.url,
        normalized_referrer: params.source,
        country_code: params.country,
        asn: params.network,
        ip_address: params.ip,
        browser: params.browser,
      })
        .filter(([, value]) => value !== undefined && value !== null)
        .map(([facet, value]) => [facet, value === "__null__" ? null : value])
    );

    if (filters.asn && /^\d+$/.test(filters.asn)) {
      filters.asn = Number(filters.asn);
    }

    return filters;
  }

  filterParams(filters) {
    return Object.fromEntries(
      Object.entries(filters).map(([facet, value]) => [
        FILTER_QUERY_PARAMS[facet],
        value === null ? "__null__" : value,
      ])
    );
  }

  titleToken() {
    return i18n("admin.browser_traffic.title");
  }
}
