import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import {
  DEFAULT_PERIOD,
  PERIOD_CUSTOM,
} from "discourse/admin/lib/dashboard-date-range";
import {
  endDate as resolveEndDate,
  FILTER_KEYS,
  safePeriod,
  selectedTrafficTypes as resolveSelectedTrafficTypes,
  startDate as resolveStartDate,
  TRAFFIC_TYPES,
} from "discourse/admin/lib/site-traffic-model";
import { i18n } from "discourse-i18n";

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

  queryParams = ["range", "start_date", "end_date", ...FILTER_KEYS];

  get safePeriod() {
    return safePeriod({
      range: this.range,
      start_date: this.start_date,
      end_date: this.end_date,
    });
  }

  get startDate() {
    return resolveStartDate({
      range: this.range,
      start_date: this.start_date,
      end_date: this.end_date,
    });
  }

  get endDate() {
    return resolveEndDate({
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
    return resolveSelectedTrafficTypes(this.traffic_type);
  }

  get traffic() {
    return this.model?.traffic ?? null;
  }

  get fetchError() {
    return this.model?.fetchError ?? null;
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
    this.model = null;
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
