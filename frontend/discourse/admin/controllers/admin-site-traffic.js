import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  calculatePresetStartDate,
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
  VALID_PERIODS,
} from "discourse/admin/lib/dashboard-date-range";
import { ajax } from "discourse/lib/ajax";
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
const TRAFFIC_TYPE_LABEL_KEYS = {
  logged_in: "logged_in_human",
  anonymous: "anonymous_human",
  likely_crawler: "likely_crawler",
};

const DIMENSION_KEYS = {
  top_url: "top_urls",
  entry_url: "entry_urls",
  referrer: "referrers",
  country: "countries",
  network: "networks",
  browser: "browsers",
  ip: "ip_addresses",
};

export default class AdminSiteTrafficController extends Controller {
  @service loadingSlider;

  @tracked range = DEFAULT_PERIOD;
  @tracked start_date = null;
  @tracked end_date = null;
  @tracked traffic_type = null;
  @tracked top_url = null;
  @tracked entry_url = null;
  @tracked referrer = null;
  @tracked country = null;
  @tracked network = null;
  @tracked browser = null;
  @tracked ip = null;
  @tracked traffic = null;
  @tracked fetchError = null;
  @tracked loadingTraffic = false;

  queryParams = ["range", "start_date", "end_date", ...FILTER_KEYS];
  #trafficLoadId = 0;
  #ownsLoadingSlider = false;

  get safePeriod() {
    if (!VALID_PERIODS.includes(this.range)) {
      return DEFAULT_PERIOD;
    }
    if (this.range === PERIOD_CUSTOM && (!this.start_date || !this.end_date)) {
      return DEFAULT_PERIOD;
    }
    return this.range;
  }

  get startDate() {
    return (
      this.#customDate(this.start_date, "startOf") ??
      calculatePresetStartDate(this.safePeriod)
    );
  }

  get endDate() {
    return (
      this.#customDate(this.end_date, "endOf") ?? moment().endOf("day").toDate()
    );
  }

  get hasPageviews() {
    return (this.traffic?.series ?? []).some(
      (row) =>
        (row.pageviews ?? 0) > 0 || (row.likely_crawler_pageviews ?? 0) > 0
    );
  }

  get activeFilters() {
    return FILTER_KEYS.flatMap((key) => {
      const values =
        key === "traffic_type"
          ? this.traffic_type === null
            ? []
            : this.selectedTrafficTypes
          : [this[key]];

      return values
        .filter((value) => value !== null)
        .map((value) => {
          const rows = this.traffic?.dimensions?.[DIMENSION_KEYS[key]] ?? [];
          const activeFilter = this.traffic?.active_filters?.find(
            (filter) => filter.key === key && filter.value === value
          );
          const label =
            activeFilter?.label ??
            rows.find((row) => row.value === value)?.label;

          return {
            key,
            value,
            label:
              label ??
              (key === "traffic_type"
                ? i18n(
                    `admin.site_traffic_explorer.series.${TRAFFIC_TYPE_LABEL_KEYS[value]}`
                  )
                : key === "referrer" && value === ""
                  ? i18n("admin.site_traffic_explorer.direct_or_unknown")
                  : value),
          };
        });
    });
  }

  get selectedTrafficTypes() {
    if (this.traffic_type === null) {
      return TRAFFIC_TYPES;
    }

    const selected = this.traffic_type.split(",");
    return TRAFFIC_TYPES.filter((trafficType) =>
      selected.includes(trafficType)
    );
  }

  get initialLoading() {
    return this.loadingTraffic && this.traffic === null;
  }

  #customDate(value, edge) {
    if (this.safePeriod !== PERIOD_CUSTOM || !value) {
      return null;
    }

    const parsed = moment(value, "YYYY-MM-DD", true);
    return parsed.isValid() ? parsed[edge]("day").toDate() : null;
  }

  @action
  setPeriod(period) {
    this.range = period;
    this.start_date = null;
    this.end_date = null;
  }

  @action
  async fetchTraffic() {
    const id = ++this.#trafficLoadId;
    const requestParams = {
      start_date: moment(this.startDate).format("YYYY-MM-DD"),
      end_date: moment(this.endDate).format("YYYY-MM-DD"),
    };

    for (const key of FILTER_KEYS) {
      if (this[key] !== null) {
        requestParams[key] = this[key];
      }
    }

    const isInitialLoad = this.traffic === null;
    this.loadingTraffic = true;
    this.fetchError = null;

    if (!isInitialLoad && !this.#ownsLoadingSlider) {
      this.#ownsLoadingSlider = this.loadingSlider.transitionStarted({
        fallbackSpinnerDelayMs: null,
      });
    }

    try {
      const traffic = await ajax(
        "/admin/dashboard/site-traffic-explorer.json",
        { data: requestParams }
      );

      if (id !== this.#trafficLoadId) {
        return;
      }

      this.traffic = {
        ...traffic,
        chart_start_date: requestParams.start_date,
        chart_end_date: requestParams.end_date,
        chart_traffic_types: this.selectedTrafficTypes,
      };
    } catch (error) {
      if (id !== this.#trafficLoadId) {
        return;
      }

      this.fetchError =
        error.jqXHR?.responseJSON?.error_type === "traffic_query_timeout"
          ? "timeout"
          : "unexpected";
    } finally {
      if (id === this.#trafficLoadId) {
        if (this.#ownsLoadingSlider) {
          this.loadingSlider.transitionEnded();
          this.#ownsLoadingSlider = false;
        }
        this.loadingTraffic = false;
      }
    }
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.range = PERIOD_CUSTOM;
    this.start_date = moment(startDate).format("YYYY-MM-DD");
    this.end_date = moment(endDate).format("YYYY-MM-DD");
  }

  @action
  setFilter(key, row) {
    this[key] = row.value;
  }

  @action
  toggleTrafficType(trafficType) {
    const selectedTrafficTypes = this.selectedTrafficTypes;
    const nextTrafficTypes = selectedTrafficTypes.includes(trafficType)
      ? selectedTrafficTypes.filter((selected) => selected !== trafficType)
      : [...selectedTrafficTypes, trafficType];

    this.#setTrafficTypes(nextTrafficTypes);
  }

  @action
  removeFilter(key, value) {
    if (key === "traffic_type") {
      const remainingTrafficTypes = this.selectedTrafficTypes.filter(
        (trafficType) => trafficType !== value
      );
      this.#setTrafficTypes(remainingTrafficTypes);
      return;
    }

    this[key] = null;
  }

  @action
  resetState() {
    this.#trafficLoadId += 1;
    if (this.#ownsLoadingSlider) {
      this.loadingSlider.transitionEnded();
      this.#ownsLoadingSlider = false;
    }
    this.traffic = null;
    this.fetchError = null;
    this.loadingTraffic = false;
    this.range = DEFAULT_PERIOD;
    this.start_date = null;
    this.end_date = null;
    for (const key of FILTER_KEYS) {
      this[key] = null;
    }
  }

  #setTrafficTypes(trafficTypes) {
    const orderedTrafficTypes = TRAFFIC_TYPES.filter((trafficType) =>
      trafficTypes.includes(trafficType)
    );

    this.traffic_type =
      orderedTrafficTypes.length === 0 ||
      orderedTrafficTypes.length === TRAFFIC_TYPES.length
        ? null
        : orderedTrafficTypes.join(",");
  }
}
