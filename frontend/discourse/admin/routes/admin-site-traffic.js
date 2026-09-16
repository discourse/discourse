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
  "language",
  "ip",
];

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
    language: { refreshModel: true },
    ip: { refreshModel: true },
  };
  #refreshTransition = null;

  titleToken() {
    return i18n("admin.site_traffic_explorer.title");
  }

  model(params) {
    const requestParams = this.#requestParams(params);

    return ajax("/admin/dashboard/site-traffic-explorer.json", {
      data: requestParams,
    })
      .then((traffic) => ({
        traffic: {
          ...traffic,
          chart_start_date: requestParams.start_date,
          chart_end_date: requestParams.end_date,
        },
        fetchError: null,
      }))
      .catch((error) => ({
        traffic: null,
        fetchError:
          error.jqXHR?.responseJSON?.error_type === "traffic_query_timeout"
            ? "timeout"
            : "unexpected",
      }));
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.loadTraffic(model);
  }

  @action
  loading(transition) {
    if (!this.controllerFor("admin-site-traffic").model) {
      this.intermediateTransitionTo("adminSiteTraffic_loading");
      return false;
    }

    this.#refreshTransition = transition;
    this.loadingSlider.transitionStarted({ showFallbackSpinner: false });
    transition.finally(() => {
      if (this.#refreshTransition !== transition) {
        return;
      }

      this.#refreshTransition = null;
      this.loadingSlider.transitionEnded();
    });
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
      const values = this.#filterValues(key, params[key]);
      if (values.length) {
        requestParams[key] = values;
      }
    }

    return requestParams;
  }

  #filterValues(key, value) {
    if (value === null || value === undefined) {
      return [];
    }

    if (value === "") {
      return ["referrer", "language"].includes(key) ? [value] : [];
    }

    if (value.startsWith("[")) {
      try {
        const values = JSON.parse(value);
        if (
          Array.isArray(values) &&
          values.every((item) => typeof item === "string")
        ) {
          return values;
        }
      } catch {
        return [];
      }
    }

    return key === "traffic_type" ? value.split(",") : [value];
  }
}
