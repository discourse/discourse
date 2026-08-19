import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import {
  calculatePresetStartDate,
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
  VALID_PERIODS,
} from "discourse/admin/lib/dashboard-date-range";
import { countryName } from "discourse/admin/lib/format-country";
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
  @tracked loading = false;
  @tracked fetchError = null;

  queryParams = ["range", "start_date", "end_date", ...FILTER_KEYS];

  get safePeriod() {
    return this.#safePeriod({
      range: this.range,
      start_date: this.start_date,
      end_date: this.end_date,
    });
  }

  get startDate() {
    return this.#startDate({
      range: this.range,
      start_date: this.start_date,
      end_date: this.end_date,
    });
  }

  get endDate() {
    return this.#endDate({
      range: this.range,
      start_date: this.start_date,
      end_date: this.end_date,
    });
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
    return this.#selectedTrafficTypes(this.traffic_type);
  }

  #safePeriod({ range, start_date, end_date }) {
    if (!VALID_PERIODS.includes(range)) {
      return DEFAULT_PERIOD;
    }
    if (range === PERIOD_CUSTOM && (!start_date || !end_date)) {
      return DEFAULT_PERIOD;
    }
    return range;
  }

  #startDate(params) {
    return (
      this.#customDate(params.start_date, "startOf", params) ??
      calculatePresetStartDate(this.#safePeriod(params))
    );
  }

  #endDate(params) {
    return (
      this.#customDate(params.end_date, "endOf", params) ??
      moment().endOf("day").toDate()
    );
  }

  #customDate(value, edge, params) {
    if (this.#safePeriod(params) !== PERIOD_CUSTOM || !value) {
      return null;
    }

    const parsed = moment(value, "YYYY-MM-DD", true);
    return parsed.isValid() ? parsed[edge]("day").toDate() : null;
  }

  #requestParams(params) {
    const requestParams = {
      start_date: moment(this.#startDate(params)).format("YYYY-MM-DD"),
      end_date: moment(this.#endDate(params)).format("YYYY-MM-DD"),
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

  #localizeCountryLabels(traffic) {
    const countries = traffic.dimensions?.countries ?? [];
    const activeFilters = traffic.active_filters ?? [];

    return {
      ...traffic,
      dimensions: {
        ...traffic.dimensions,
        countries: countries.map((row) => ({
          ...row,
          label: countryName(row.value),
        })),
      },
      active_filters: activeFilters.map((filter) =>
        filter.key === "country"
          ? { ...filter, label: countryName(filter.value) }
          : filter
      ),
    };
  }

  async loadTraffic(params) {
    const selectedStartDate = this.#startDate(params);
    const selectedEndDate = this.#endDate(params);

    try {
      const traffic = await ajax(
        "/admin/dashboard/site-traffic-explorer.json",
        { data: this.#requestParams(params) }
      );

      return {
        traffic: {
          ...this.#localizeCountryLabels(traffic),
          chart_start_date: moment(selectedStartDate).format("YYYY-MM-DD"),
          chart_end_date: moment(selectedEndDate).format("YYYY-MM-DD"),
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

  applyTrafficModel({ traffic, fetchError }) {
    if (traffic) {
      this.traffic = traffic;
    }
    this.fetchError = fetchError;
  }

  @action
  setPeriod(period) {
    this.range = period;
    this.start_date = null;
    this.end_date = null;
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
    this.range = DEFAULT_PERIOD;
    this.start_date = null;
    this.end_date = null;
    for (const key of FILTER_KEYS) {
      this[key] = null;
    }
    this.traffic = null;
    this.loading = false;
    this.fetchError = null;
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
