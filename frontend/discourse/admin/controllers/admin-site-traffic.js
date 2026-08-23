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
const DIMENSION_LIMIT = 50;
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
  @tracked fetchError = null;
  @tracked draftFilters = Object.fromEntries(
    FILTER_KEYS.map((key) => [key, []])
  );

  queryParams = ["range", "start_date", "end_date", ...FILTER_KEYS];

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
    const pending = this.hasPendingFilters;

    return FILTER_KEYS.filter((key) => this.draftFilters[key].length).map(
      (key) => ({
        key,
        pending,
        values: this.draftFilters[key].map((value) => ({
          value,
          label: this.#filterLabel(key, value),
        })),
      })
    );
  }

  get selectedTrafficTypes() {
    const values = this.draftFilters.traffic_type;
    if (values.length === 0) {
      return TRAFFIC_TYPES;
    }

    return TRAFFIC_TYPES.filter((trafficType) => values.includes(trafficType));
  }

  get hasPendingFilters() {
    return FILTER_KEYS.some(
      (key) =>
        !this.#sameValues(this.draftFilters[key], this.#appliedValues(key))
    );
  }

  get pendingFilterCount() {
    return FILTER_KEYS.reduce(
      (count, key) => count + this.draftFilters[key].length,
      0
    );
  }

  #customDate(value, edge) {
    if (this.safePeriod !== PERIOD_CUSTOM || !value) {
      return null;
    }

    const parsed = moment(value, "YYYY-MM-DD", true);
    return parsed.isValid() ? parsed[edge]("day").toDate() : null;
  }

  #decorateTraffic(traffic) {
    const countries = traffic.dimensions?.countries ?? [];
    const activeFilters = (traffic.active_filters ?? []).map((filter) =>
      filter.key === "country"
        ? { ...filter, label: countryName(filter.value) }
        : filter
    );
    const dimensions = {
      ...traffic.dimensions,
      countries: countries.map((row) => ({
        ...row,
        label: countryName(row.value),
      })),
    };

    for (const [filterKey, dimensionKey] of Object.entries(DIMENSION_KEYS)) {
      const rows = dimensions[dimensionKey] ?? [];
      const activeRows = activeFilters.filter(
        (filter) => filter.key === filterKey
      );
      if (activeRows.length === 0) {
        continue;
      }

      const activeValues = new Set(activeRows.map((filter) => filter.value));
      const rowsByValue = new Map(rows.map((row) => [row.value, row]));
      dimensions[dimensionKey] = [
        ...activeRows.map(
          (filter) =>
            rowsByValue.get(filter.value) ?? {
              value: filter.value,
              label: filter.label,
              pageviews: 0,
            }
        ),
        ...rows.filter((row) => !activeValues.has(row.value)),
      ].slice(0, DIMENSION_LIMIT);
    }

    return {
      ...traffic,
      dimensions,
      active_filters: activeFilters,
    };
  }

  loadTraffic(model) {
    this.#resetDraftFilters();
    this.traffic = model.traffic ? this.#decorateTraffic(model.traffic) : null;
    this.fetchError = model.fetchError;
    this.#reconcileFilters(this.traffic?.active_filters ?? []);
  }

  @action
  setPeriod(period) {
    this.#resetDraftFilters();
    this.range = period;
    this.start_date = null;
    this.end_date = null;
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.#resetDraftFilters();
    this.range = PERIOD_CUSTOM;
    this.start_date = moment(startDate).format("YYYY-MM-DD");
    this.end_date = moment(endDate).format("YYYY-MM-DD");
  }

  @action
  toggleFilter(key, row) {
    const values = this.draftFilters[key];
    this.#setDraftValues(
      key,
      values.includes(row.value)
        ? values.filter((value) => value !== row.value)
        : [...values, row.value]
    );
  }

  @action
  toggleTrafficType(trafficType) {
    const selectedTrafficTypes = this.selectedTrafficTypes;
    const nextTrafficTypes = selectedTrafficTypes.includes(trafficType)
      ? selectedTrafficTypes.filter((selected) => selected !== trafficType)
      : [...selectedTrafficTypes, trafficType];

    this.#setDraftValues(
      "traffic_type",
      nextTrafficTypes.length === TRAFFIC_TYPES.length ? [] : nextTrafficTypes
    );
  }

  @action
  removeFilterValue(key, value) {
    this.#setDraftValues(
      key,
      this.draftFilters[key].filter((item) => item !== value)
    );
  }

  @action
  clearFilter(key) {
    this.#setDraftValues(key, []);
  }

  @action
  clearAllFilters() {
    this.draftFilters = Object.fromEntries(FILTER_KEYS.map((key) => [key, []]));

    for (const key of FILTER_KEYS) {
      this[key] = null;
    }
  }

  @action
  applyFilters() {
    for (const key of FILTER_KEYS) {
      this[key] = this.#serializeValues(this.draftFilters[key]);
    }
  }

  @action
  applyModalFilters(key, rows) {
    this.#setDraftValues(
      key,
      rows.map((row) => row.value)
    );
  }

  @action
  isFilterSelected(key, value) {
    return this.draftFilters[key].includes(value);
  }

  @action
  resetState() {
    this.range = DEFAULT_PERIOD;
    this.start_date = null;
    this.end_date = null;
    for (const key of FILTER_KEYS) {
      this[key] = null;
    }
    this.#resetDraftFilters();
    this.traffic = null;
    this.fetchError = null;
  }

  #appliedValues(key) {
    const value = this[key];
    if (value === null) {
      return [];
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
        // The server will validate malformed values when the request runs.
      }
    }

    return key === "traffic_type" ? value.split(",") : [value];
  }

  #filterLabel(key, value) {
    const rows = this.traffic?.dimensions?.[DIMENSION_KEYS[key]] ?? [];
    const activeFilter = this.traffic?.active_filters?.find(
      (filter) => filter.key === key && filter.value === value
    );
    const label =
      activeFilter?.label ?? rows.find((row) => row.value === value)?.label;

    if (label) {
      return label;
    }
    if (key === "traffic_type") {
      return i18n(
        `admin.site_traffic_explorer.series.${TRAFFIC_TYPE_LABEL_KEYS[value]}`
      );
    }
    if (key === "referrer" && value === "") {
      return i18n("admin.site_traffic_explorer.direct_or_unknown");
    }
    return value;
  }

  #resetDraftFilters() {
    this.draftFilters = Object.fromEntries(
      FILTER_KEYS.map((key) => [key, [...this.#appliedValues(key)]])
    );
  }

  #reconcileFilters(activeFilters) {
    const filters = Object.fromEntries(FILTER_KEYS.map((key) => [key, []]));

    for (const filter of activeFilters) {
      filters[filter.key].push(filter.value);
    }
    for (const key of FILTER_KEYS) {
      if (!this.#sameValues(filters[key], this.#appliedValues(key))) {
        this[key] = this.#serializeValues(filters[key]);
      }
    }

    this.draftFilters = filters;
  }

  #setDraftValues(key, values) {
    this.draftFilters = { ...this.draftFilters, [key]: values };

    const hasDraftFilters = FILTER_KEYS.some(
      (filterKey) => this.draftFilters[filterKey].length
    );
    const hasAppliedFilters = FILTER_KEYS.some(
      (filterKey) => this.#appliedValues(filterKey).length
    );
    if (!hasDraftFilters && hasAppliedFilters) {
      this.applyFilters();
    }
  }

  #sameValues(first, second) {
    return (
      first.length === second.length &&
      first.every((value, index) => value === second[index])
    );
  }

  #serializeValues(values) {
    if (values.length === 0) {
      return null;
    }
    return values.length === 1 ? values[0] : JSON.stringify(values);
  }
}
