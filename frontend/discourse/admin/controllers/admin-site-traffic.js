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
  "top_url",
  "entry_url",
  "referrer",
  "country",
  "network",
  "browser",
  "ip",
];

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

  @tracked range = null;
  @tracked start_date = null;
  @tracked end_date = null;
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

  defaultPeriod = DEFAULT_PERIOD;
  #fetchId = 0;
  #loadingCount = 0;

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
    return (this.traffic?.summary?.pageviews ?? 0) > 0;
  }

  get activeFilters() {
    return FILTER_KEYS.filter((key) => this[key] !== null).map((key) => {
      const value = this[key];
      const rows = this.traffic?.dimensions?.[DIMENSION_KEYS[key]] ?? [];
      const label = rows.find((row) => row.value === value)?.label;

      return {
        key,
        value,
        label:
          label ??
          (key === "referrer" && value === ""
            ? i18n("admin.site_traffic_explorer.direct_or_unknown")
            : value),
      };
    });
  }

  #customDate(value, edge) {
    if (this.safePeriod !== PERIOD_CUSTOM || !value) {
      return null;
    }

    const parsed = moment(value, "YYYY-MM-DD", true);
    return parsed.isValid() ? parsed[edge]("day").toDate() : null;
  }

  #requestParams() {
    const params = {
      start_date: moment(this.startDate).format("YYYY-MM-DD"),
      end_date: moment(this.endDate).format("YYYY-MM-DD"),
    };

    for (const key of FILTER_KEYS) {
      if (this[key] !== null) {
        params[key] = this[key];
      }
    }

    return params;
  }

  @action
  async fetchTraffic() {
    const fetchId = ++this.#fetchId;
    this.loading = true;
    this.fetchError = null;
    this.#loadingCount++;
    if (this.#loadingCount === 1) {
      this.loadingSlider.transitionStarted();
    }

    try {
      const traffic = await ajax("/admin/dashboard/traffic.json", {
        data: this.#requestParams(),
      });

      if (fetchId === this.#fetchId) {
        this.traffic = traffic;
      }
    } catch (error) {
      if (fetchId === this.#fetchId) {
        this.fetchError =
          error.jqXHR?.responseJSON?.error_type === "traffic_query_timeout"
            ? "timeout"
            : "unexpected";
      }
    } finally {
      this.#loadingCount = Math.max(this.#loadingCount - 1, 0);
      if (this.#loadingCount === 0) {
        this.loadingSlider.transitionEnded();
      }
      if (fetchId === this.#fetchId) {
        this.loading = false;
      }
    }
  }

  @action
  setPeriod(period) {
    this.range = period;
    this.start_date = null;
    this.end_date = null;
    this.fetchTraffic();
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.range = PERIOD_CUSTOM;
    this.start_date = moment(startDate).format("YYYY-MM-DD");
    this.end_date = moment(endDate).format("YYYY-MM-DD");
    this.fetchTraffic();
  }

  @action
  setFilter(key, row) {
    this[key] = row.value;
    this.fetchTraffic();
  }

  @action
  removeFilter(key) {
    this[key] = null;
    this.fetchTraffic();
  }

  @action
  clearFilters() {
    for (const key of FILTER_KEYS) {
      this[key] = null;
    }
    this.fetchTraffic();
  }

  @action
  resetState() {
    this.#fetchId++;
    this.range = null;
    this.start_date = null;
    this.end_date = null;
    for (const key of FILTER_KEYS) {
      this[key] = null;
    }
    this.traffic = null;
    this.loading = false;
    this.fetchError = null;
  }
}
