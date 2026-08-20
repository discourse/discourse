import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  calculatePresetStartDate,
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
  VALID_PERIODS,
} from "discourse/admin/lib/dashboard-date-range";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const FILTER_KEYS = [
  "traffic_type",
  "top_url",
  "entry_url",
  "referrer",
  "country",
  "network",
  "browser",
  "ip",
];

const TRAFFIC_TYPES = ["logged_in", "anonymous", "likely_crawler"];

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
      const requestParams = this.#requestParams(params);
      const traffic = await ajax(
        "/admin/dashboard/site-traffic-explorer.json",
        { data: requestParams }
      );

      return {
        traffic: {
          ...traffic,
          chart_start_date: requestParams.start_date,
          chart_end_date: requestParams.end_date,
          chart_traffic_types: this.#selectedTrafficTypes(params.traffic_type),
        },
        fetchError: null,
      };
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
    if (this.controllerFor("admin-site-traffic").traffic === null) {
      this.intermediateTransitionTo("adminSiteTraffic_loading");
      return false;
    }

    this.loadingSlider.transitionStarted({ showFallbackSpinner: false });
    transition.finally(() => this.loadingSlider.transitionEnded());
    return false;
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.resetState();
    }
  }

  #safePeriod(params) {
    if (!VALID_PERIODS.includes(params.range)) {
      return DEFAULT_PERIOD;
    }
    if (
      params.range === PERIOD_CUSTOM &&
      (!params.start_date || !params.end_date)
    ) {
      return DEFAULT_PERIOD;
    }
    return params.range;
  }

  #customDate(value, edge, period) {
    if (period !== PERIOD_CUSTOM || !value) {
      return null;
    }

    const parsed = moment(value, "YYYY-MM-DD", true);
    return parsed.isValid() ? parsed[edge]("day").toDate() : null;
  }

  #requestParams(params) {
    const period = this.#safePeriod(params);
    const startDate =
      this.#customDate(params.start_date, "startOf", period) ??
      calculatePresetStartDate(period);
    const endDate =
      this.#customDate(params.end_date, "endOf", period) ??
      moment().endOf("day").toDate();

    const requestParams = {
      start_date: moment(startDate).format("YYYY-MM-DD"),
      end_date: moment(endDate).format("YYYY-MM-DD"),
    };

    for (const key of FILTER_KEYS) {
      if (params[key] !== null && params[key] !== undefined) {
        requestParams[key] = params[key];
      }
    }

    return requestParams;
  }

  #selectedTrafficTypes(value) {
    if (!value) {
      return TRAFFIC_TYPES;
    }

    const selected = value.split(",");
    return TRAFFIC_TYPES.filter((trafficType) =>
      selected.includes(trafficType)
    );
  }
}
