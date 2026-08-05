import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import SiteTrafficMetric from "discourse/admin/components/dashboard/site-traffic-metric";
import SiteTrafficBreakdownModal from "discourse/admin/components/modal/site-traffic-breakdown";
import { countryFlag, countryName } from "discourse/admin/lib/format-country";
import { formatMinutesSeconds } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import Session from "discourse/models/session";
import { eq, gt } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import I18n, { i18n } from "discourse-i18n";

const SAFE_FILTERS = new Set(["country", "asn", "browser"]);
const SENSITIVE_FILTERS = new Set(["url", "ip"]);
const BROWSER_FAMILIES = new Set([
  "edge",
  "opera",
  "firefox",
  "chrome",
  "safari",
  "ie",
  "discoursehub",
  "unknown",
]);
const FILTER_DIMENSIONS = {
  top_urls: "url",
  countries: "country",
  networks: "asn",
  browsers: "browser",
  ip_addresses: "ip",
};
const SERIES = [
  {
    key: "logged_in_human_pageviews",
    req: "logged-in-human",
    color: "#4B3CE0",
  },
  {
    key: "anonymous_human_pageviews",
    req: "anonymous-human",
    color: "#9C8DEC",
  },
  {
    key: "likely_crawler_pageviews",
    req: "likely-crawler",
    color: "#D5CDF7",
  },
];
const SKELETON_KPIS = Array.from({ length: 7 });
const SKELETON_CARDS = Array.from({ length: 4 });
const SKELETON_ROWS = Array.from({ length: 5 });

export default class SiteTrafficDetail extends Component {
  @service currentUser;
  @service modal;
  @service sessionStore;

  @tracked data;
  @tracked loading = false;
  @tracked error;
  @tracked filters = {};
  @tracked pagesTab = "top_urls";
  @tracked geographyTab = "countries";

  abortController;
  requestId = 0;
  chartOptions = { hideYAxisGridLines: true, hiddenLabels: [] };

  constructor() {
    super(...arguments);
    this.filters = {
      ...this.#fragmentFilters(),
      ...this.#storedSensitiveFilters(),
    };
    this.load();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.requestId += 1;
    this.abortController?.abort();
  }

  get analysis() {
    return this.data?.analysis || {};
  }

  get analysisWarning() {
    return this.analysis.retention_truncated || this.analysis.cap_truncated;
  }

  get dimensions() {
    return this.data?.dimensions || {};
  }

  get summary() {
    return this.data?.summary || {};
  }

  get formattedPageviews() {
    return this.#formatNumber(this.summary.pageviews);
  }

  get formattedLoggedInHumanPageviews() {
    return this.#formatNumber(this.summary.logged_in_human_pageviews);
  }

  get formattedAnonymousHumanPageviews() {
    return this.#formatNumber(this.summary.anonymous_human_pageviews);
  }

  get formattedLikelyCrawlerPageviews() {
    return this.#formatNumber(this.summary.likely_crawler_pageviews);
  }

  get formattedDistinctSessions() {
    return this.#formatNumber(this.summary.distinct_sessions);
  }

  get formattedBounceRate() {
    return this.summary.bounce_rate == null
      ? "—"
      : `${I18n.toNumber(this.summary.bounce_rate, { precision: 0 })}%`;
  }

  get formattedAverageDuration() {
    return this.summary.average_session_duration_seconds == null
      ? "—"
      : formatMinutesSeconds(this.summary.average_session_duration_seconds);
  }

  get errorMessage() {
    return i18n(
      `admin.dashboard.site_traffic.details.errors.${
        this.error?.error_type || "unexpected"
      }`
    );
  }

  get showRetry() {
    return (
      this.error?.error_type === "timeout" ||
      this.error?.error_type === "unexpected"
    );
  }

  get showSkeleton() {
    return this.loading && !this.data;
  }

  get activeFilterEntries() {
    return Object.entries(this.filters).map(([dimension, value]) => ({
      dimension,
      value,
      label: this.#filterLabel(dimension, value),
    }));
  }

  get hasFilters() {
    return this.activeFilterEntries.length > 0;
  }

  get pageRows() {
    return this.#displayRows(this.pagesTab);
  }

  get pageCardTitle() {
    return i18n(
      `admin.dashboard.site_traffic.details.dimensions.${this.pagesTab}`
    );
  }

  get pageCardInformational() {
    return this.pagesTab === "entry_urls";
  }

  get standaloneCards() {
    return ["traffic_sources", "browsers"].map((key) => ({
      key,
      title: i18n(`admin.dashboard.site_traffic.details.dimensions.${key}`),
      rows: this.#displayRows(key),
      informational: key === "traffic_sources",
    }));
  }

  get trafficSourcesCard() {
    return this.standaloneCards[0];
  }

  get browsersCard() {
    return this.standaloneCards[1];
  }

  get geographyRows() {
    return this.#displayRows(this.geographyTab);
  }

  get geographyCardTitle() {
    return i18n(
      `admin.dashboard.site_traffic.details.dimensions.${this.geographyTab}`
    );
  }

  get chartModel() {
    return {
      start_date: this.args.startDate,
      end_date: this.args.endDate,
      data: SERIES.map((series) => ({
        req: series.req,
        label: i18n(
          `admin.dashboard.site_traffic.details.series.${series.req}`
        ),
        color: series.color,
        data: (this.data?.series || []).map((point) => ({
          x: point.date,
          y: point[series.key],
        })),
      })),
    };
  }

  get requestedRange() {
    return this.#formatDateRange(
      this.analysis.requested_start_date,
      this.analysis.requested_end_date
    );
  }

  get availableRange() {
    return this.#formatDateRange(
      this.analysis.available_start_at,
      this.analysis.available_end_at
    );
  }

  get analyzedRange() {
    return this.#formatTimestampRange(
      this.analysis.analyzed_start_at,
      this.analysis.analyzed_end_at
    );
  }

  get formattedAnalyzedCount() {
    return this.#formatNumber(this.analysis.analyzed_event_count);
  }

  get formattedEventCap() {
    return this.#formatNumber(this.analysis.event_cap);
  }

  cardRows(rows) {
    return rows.slice(0, 8);
  }

  countryFlag(value) {
    return countryFlag(value);
  }

  @action
  datesChanged() {
    this.#persistSensitiveFilters();
    this.load();
  }

  @action
  async load() {
    const requestId = ++this.requestId;
    this.abortController?.abort();
    this.abortController = new AbortController();
    this.loading = true;
    this.error = null;

    try {
      const response = await window.fetch(
        getURL("/admin/dashboard/traffic.json"),
        {
          method: "POST",
          credentials: "same-origin",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": Session.currentProp("csrfToken"),
          },
          signal: this.abortController.signal,
          body: JSON.stringify({
            start_date: this.args.startDate,
            end_date: this.args.endDate,
            filters: this.filters,
          }),
        }
      );
      const body = await response.json();

      if (!response.ok) {
        const failure = new Error("Site traffic request failed");
        failure.responseJSON = body;
        throw failure;
      }

      if (requestId === this.requestId) {
        this.data = body;
      }
    } catch (error) {
      if (requestId === this.requestId && error?.name !== "AbortError") {
        this.error = error.responseJSON || { error_type: "unexpected" };
      }
    } finally {
      if (requestId === this.requestId) {
        this.loading = false;
      }
    }
  }

  @action
  applyFilter(dimension, value) {
    this.filters = { ...this.filters, [dimension]: value };
    this.#persistFilters();
    this.load();
  }

  @action
  removeFilter(dimension) {
    const filters = { ...this.filters };
    delete filters[dimension];
    this.filters = filters;
    this.#persistFilters();
    this.load();
  }

  @action
  clearFilters() {
    this.filters = {};
    this.#persistFilters();
    this.load();
  }

  @action
  selectPagesTab(tab) {
    this.pagesTab = tab;
  }

  @action
  selectGeographyTab(tab) {
    this.geographyTab = tab;
  }

  @action
  navigatePagesTabs(event) {
    const tabs = ["top_urls", "entry_urls"];
    const currentIndex = tabs.indexOf(this.pagesTab);
    let nextIndex;

    if (event.key === "ArrowRight") {
      nextIndex = (currentIndex + 1) % tabs.length;
    } else if (event.key === "ArrowLeft") {
      nextIndex = (currentIndex - 1 + tabs.length) % tabs.length;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = tabs.length - 1;
    } else {
      return;
    }

    event.preventDefault();
    this.pagesTab = tabs[nextIndex];
    event.currentTarget.parentElement
      .querySelector(`[data-site-traffic-tab="${this.pagesTab}"]`)
      ?.focus();
  }

  @action
  navigateGeographyTabs(event) {
    const tabs = ["countries", "networks", "ip_addresses"];
    const currentIndex = tabs.indexOf(this.geographyTab);
    let nextIndex;

    if (event.key === "ArrowRight") {
      nextIndex = (currentIndex + 1) % tabs.length;
    } else if (event.key === "ArrowLeft") {
      nextIndex = (currentIndex - 1 + tabs.length) % tabs.length;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = tabs.length - 1;
    } else {
      return;
    }

    event.preventDefault();
    this.geographyTab = tabs[nextIndex];
    event.currentTarget.parentElement
      .querySelector(`[data-site-traffic-geography-tab="${this.geographyTab}"]`)
      ?.focus();
  }

  @action
  showMore(dimension, title, rows) {
    this.modal.show(SiteTrafficBreakdownModal, {
      model: {
        title,
        rows,
        onSelect: (row) => {
          const filterDimension = FILTER_DIMENSIONS[dimension];
          if (filterDimension && row.filterable) {
            this.applyFilter(filterDimension, row.value);
          }
        },
      },
    });
  }

  @action
  focusDateRange() {
    document.querySelector(".db-date-range__trigger")?.focus();
  }

  #displayRows(dimension) {
    return (this.dimensions[dimension] || []).map((row) => ({
      ...row,
      displayLabel: this.#rowLabel(dimension, row),
      formattedPageviews: this.#formatNumber(row.pageviews),
    }));
  }

  #rowLabel(dimension, row) {
    if (dimension === "countries") {
      return countryName(row.value) || row.label;
    }

    if (dimension === "browsers") {
      return i18n(
        `admin.dashboard.site_traffic.details.browsers.${
          BROWSER_FAMILIES.has(row.value) ? row.value : "unknown"
        }`
      );
    }

    return row.label;
  }

  #filterLabel(dimension, value) {
    const sourceDimension = {
      url: "top_urls",
      country: "countries",
      asn: "networks",
      browser: "browsers",
      ip: "ip_addresses",
    }[dimension];
    const row = (this.dimensions[sourceDimension] || []).find(
      (candidate) => candidate.value === value
    );

    if (row) {
      return this.#rowLabel(sourceDimension, row);
    }
    if (dimension === "country") {
      return countryName(value) || value;
    }
    if (dimension === "browser") {
      return i18n(
        `admin.dashboard.site_traffic.details.browsers.${
          BROWSER_FAMILIES.has(value) ? value : "unknown"
        }`
      );
    }
    return value;
  }

  #formatNumber(value) {
    return I18n.toNumber(value || 0, { precision: 0 });
  }

  #formatDateRange(startValue, endValue) {
    if (!startValue || !endValue) {
      return i18n("admin.dashboard.site_traffic.details.unavailable");
    }

    const start = moment(startValue);
    const end = moment(endValue);
    const withYear = (date) =>
      date.format(i18n("dates.long_with_year_no_time"));
    const withoutYear = (date) =>
      date.format(i18n("dates.long_no_year_no_time"));

    if (start.isSame(end, "day")) {
      return withYear(start);
    }
    if (start.year() === end.year()) {
      return `${withoutYear(start)} – ${withYear(end)}`;
    }
    return `${withYear(start)} – ${withYear(end)}`;
  }

  #formatTimestampRange(startValue, endValue) {
    if (!startValue || !endValue) {
      return i18n("admin.dashboard.site_traffic.details.unavailable");
    }

    const start = moment(startValue);
    const end = moment(endValue);
    const dateFormat = i18n("dates.long_with_year_no_time");
    const timeFormat = i18n("dates.time");

    if (start.isSame(end, "day")) {
      return `${start.format(dateFormat)}, ${start.format(
        timeFormat
      )} – ${end.format(timeFormat)}`;
    }
    return `${start.format(
      `${dateFormat}, ${timeFormat}`
    )} – ${end.format(`${dateFormat}, ${timeFormat}`)}`;
  }

  #validSafeFilter(key, value) {
    if (key === "country") {
      return /^[A-Z]{2}$/.test(value);
    }
    if (key === "asn") {
      if (!/^AS[1-9][0-9]{0,9}$/.test(value)) {
        return false;
      }
      return Number(value.slice(2)) <= 2_147_483_647;
    }
    return key === "browser" && BROWSER_FAMILIES.has(value);
  }

  #fragmentFilters() {
    const values = new URLSearchParams(window.location.hash.slice(1));
    return Object.fromEntries(
      [...SAFE_FILTERS].flatMap((key) => {
        const value = values.get(key);
        return value && this.#validSafeFilter(key, value) ? [[key, value]] : [];
      })
    );
  }

  #storedSensitiveFilters() {
    const stored = this.sessionStore.getObject(this.#storageKey());
    if (!stored || typeof stored !== "object" || Array.isArray(stored)) {
      return {};
    }

    return Object.fromEntries(
      [...SENSITIVE_FILTERS].flatMap((key) => {
        const value = stored[key];
        return typeof value === "string" && value.length ? [[key, value]] : [];
      })
    );
  }

  #persistFilters() {
    this.#writeFragment();
    this.#persistSensitiveFilters();
  }

  #writeFragment() {
    const values = new URLSearchParams();
    for (const [key, value] of Object.entries(this.filters)) {
      if (SAFE_FILTERS.has(key)) {
        values.set(key, value);
      }
    }

    const fragment = values.size ? `#${values.toString()}` : "";
    DiscourseURL.replaceState(
      `${window.location.pathname}${window.location.search}${fragment}`
    );
  }

  #persistSensitiveFilters() {
    const filters = Object.fromEntries(
      Object.entries(this.filters).filter(([key]) => SENSITIVE_FILTERS.has(key))
    );

    if (Object.keys(filters).length) {
      this.sessionStore.setObject({
        key: this.#storageKey(),
        value: filters,
      });
    } else {
      this.sessionStore.remove(this.#storageKey());
    }
  }

  #storageKey() {
    return [
      "admin-site-traffic-detail",
      window.location.host,
      this.currentUser?.id,
      getURL("/admin/dashboard/traffic"),
      this.args.startDate,
      this.args.endDate,
    ].join(":");
  }

  <template>
    <main
      class="site-traffic-detail"
      data-test-site-traffic-detail
      {{didUpdate this.datesChanged @startDate @endDate}}
    >
      <div class="site-traffic-detail__sticky-controls">
        <div
          class="site-traffic-detail__date-range"
          data-test-site-traffic-date-range
        >
          <DashboardDateRange
            @period="custom"
            @startDate={{@startDateValue}}
            @endDate={{@endDateValue}}
            @setPeriod={{@setPeriod}}
            @setCustomDateRange={{@setCustomDateRange}}
          />
        </div>

        {{#if this.hasFilters}}
          <div
            class="site-traffic-detail__active-filters"
            aria-label={{i18n
              "admin.dashboard.site_traffic.details.active_filters"
            }}
          >
            {{#each this.activeFilterEntries as |filter|}}
              <span
                class="site-traffic-detail__filter-chip"
                data-test-filter-chip={{filter.dimension}}
              >
                <span>{{filter.label}}</span>
                <button
                  type="button"
                  class="btn-flat"
                  aria-label={{i18n
                    "admin.dashboard.site_traffic.details.remove_filter"
                    filter=filter.label
                  }}
                  {{on "click" (fn this.removeFilter filter.dimension)}}
                >
                  ×
                </button>
              </span>
            {{/each}}
            <DButton
              class="site-traffic-detail__clear"
              @label="admin.dashboard.site_traffic.details.clear"
              @action={{this.clearFilters}}
            />
          </div>
        {{/if}}

        {{#if this.analysisWarning}}
          <p
            class="site-traffic-detail__partial-warning"
            data-test-analysis-warning
            role="status"
          >
            {{i18n
              "admin.dashboard.site_traffic.details.partial"
              requested=this.requestedRange
              available=this.availableRange
              analyzed=this.analyzedRange
              analyzed_count=this.formattedAnalyzedCount
              cap=this.formattedEventCap
            }}
          </p>
        {{/if}}
      </div>

      {{#if this.showSkeleton}}
        <div
          class="db-skeleton site-traffic-detail__skeleton --animation"
          data-test-traffic-loading
          role="status"
          aria-label={{i18n "admin.dashboard.site_traffic.details.loading"}}
        >
          <div class="db-skeleton__kpi-row">
            {{#each SKELETON_KPIS}}
              <div class="db-skeleton__kpi">
                <div class="db-skeleton__kpi-value"></div>
                <div class="db-skeleton__kpi-label"></div>
              </div>
            {{/each}}
          </div>
          <div class="db-skeleton__chart"></div>
          <div class="db-skeleton__report-grid">
            {{#each SKELETON_CARDS}}
              <div class="db-skeleton__report-card">
                <div class="db-skeleton__report-card-header">
                  <div class="db-skeleton__report-card-title"></div>
                  <div class="db-skeleton__report-card-label"></div>
                </div>
                <ul class="db-skeleton__list">
                  {{#each SKELETON_ROWS}}
                    <li class="db-skeleton__list-row">
                      <span class="db-skeleton__list-name"></span>
                      <span class="db-skeleton__list-value"></span>
                    </li>
                  {{/each}}
                </ul>
              </div>
            {{/each}}
          </div>
        </div>
      {{else if this.loading}}
        <p class="sr-only" data-test-traffic-loading role="status">
          {{i18n "admin.dashboard.site_traffic.details.loading"}}
        </p>
      {{/if}}

      {{#if this.error}}
        <div class="site-traffic-detail__error" role="alert">
          <p>{{this.errorMessage}}</p>
          <div class="site-traffic-detail__error-actions">
            {{#if this.showRetry}}
              <DButton
                @label="admin.dashboard.site_traffic.details.retry"
                @action={{this.load}}
              />
            {{/if}}
            {{#if (eq this.error.error_type "timeout")}}
              <DButton
                @label="admin.dashboard.site_traffic.details.narrow_range"
                @action={{this.focusDateRange}}
              />
            {{/if}}
          </div>
        </div>
      {{/if}}

      {{#if this.data}}
        <section
          class="site-traffic-detail__metrics"
          data-test-session-kpis
          aria-labelledby="site-traffic-pageview-metrics"
        >
          <h2 id="site-traffic-pageview-metrics" class="sr-only">
            {{i18n "admin.dashboard.site_traffic.details.pageview_metrics"}}
          </h2>
          <SiteTrafficMetric
            @primary={{true}}
            @label={{i18n
              "admin.dashboard.site_traffic.details.kpi.pageviews.label"
            }}
            @value={{this.formattedPageviews}}
            @tooltip={{i18n
              "admin.dashboard.site_traffic.details.kpi.pageviews.tooltip"
            }}
            @tooltipIdentifier="site-traffic-detail-pageviews-tooltip"
            data-test-metric
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.details.series.logged-in-human"
            }}
            @value={{this.formattedLoggedInHumanPageviews}}
            data-test-series-total
            data-test-traffic-series="logged-in-human"
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.details.series.anonymous-human"
            }}
            @value={{this.formattedAnonymousHumanPageviews}}
            data-test-series-total
            data-test-traffic-series="anonymous-human"
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.details.series.likely-crawler"
            }}
            @value={{this.formattedLikelyCrawlerPageviews}}
            data-test-series-total
            data-test-traffic-series="likely-crawler"
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.details.kpi.distinct_sessions.label"
            }}
            @value={{this.formattedDistinctSessions}}
            @scope={{i18n
              "admin.dashboard.site_traffic.details.overall_analyzed_period"
            }}
            @tooltip={{i18n
              "admin.dashboard.site_traffic.details.kpi.distinct_sessions.tooltip"
            }}
            @tooltipIdentifier="site-traffic-detail-sessions-tooltip"
            data-test-metric
            data-test-session-kpi
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.details.kpi.bounce_rate.label"
            }}
            @value={{this.formattedBounceRate}}
            @scope={{i18n
              "admin.dashboard.site_traffic.details.overall_analyzed_period"
            }}
            @tooltip={{i18n
              "admin.dashboard.site_traffic.kpi.bounce_rate.tooltip"
            }}
            @tooltipIdentifier="site-traffic-detail-bounce-tooltip"
            data-test-metric
            data-test-session-kpi
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.details.kpi.average_session_duration.label"
            }}
            @value={{this.formattedAverageDuration}}
            @scope={{i18n
              "admin.dashboard.site_traffic.details.overall_analyzed_period"
            }}
            @tooltip={{i18n
              "admin.dashboard.site_traffic.kpi.average_session_duration.tooltip"
            }}
            @tooltipIdentifier="site-traffic-detail-duration-tooltip"
            data-test-metric
            data-test-session-kpi
          />
          <span class="sr-only" data-test-session-scope>
            {{i18n
              "admin.dashboard.site_traffic.details.session_metrics.scope"
            }}
          </span>
          <span class="sr-only" data-test-crawler-scope>
            {{i18n
              "admin.dashboard.site_traffic.details.crawler_scope"
              state=this.analysis.crawler_scoring_state
            }}
          </span>
        </section>

        <div class="site-traffic-detail__chart">
          <AdminReportStackedChart
            @model={{this.chartModel}}
            @options={{this.chartOptions}}
          />
          {{#each this.data.series as |point|}}
            <span
              class="sr-only"
              data-test-traffic-point={{point.date}}
            >{{point.logged_in_human_pageviews}}
              {{point.anonymous_human_pageviews}}
              {{point.likely_crawler_pageviews}}</span>
          {{/each}}
        </div>

        {{#if (eq this.summary.pageviews 0)}}
          <p
            class="site-traffic-detail__empty"
            role="status"
            aria-live="polite"
          >
            {{i18n "admin.dashboard.site_traffic.details.empty"}}
          </p>
        {{else}}
          <div class="site-traffic-detail__cards">
            <section
              class="site-traffic-detail__card"
              data-test-breakdown={{this.trafficSourcesCard.key}}
            >
              <div class="site-traffic-detail__card-header">
                <h2>{{this.trafficSourcesCard.title}}</h2>
              </div>
              <ul class="site-traffic-detail__breakdown-list">
                {{#each (this.cardRows this.trafficSourcesCard.rows) as |row|}}
                  <li>
                    <span
                      class="site-traffic-detail__row"
                      data-test-breakdown-row
                    >
                      <span>{{row.displayLabel}}</span>
                      <strong>{{row.formattedPageviews}}</strong>
                    </span>
                  </li>
                {{/each}}
              </ul>
              {{#if (gt this.trafficSourcesCard.rows.length 8)}}
                <DButton
                  @label="admin.dashboard.site_traffic.details.view_more"
                  @action={{fn
                    this.showMore
                    this.trafficSourcesCard.key
                    this.trafficSourcesCard.title
                    this.trafficSourcesCard.rows
                  }}
                />
              {{/if}}
            </section>

            <section
              class="site-traffic-detail__card"
              data-test-breakdown="pages"
            >
              <div class="site-traffic-detail__card-header">
                <h2>
                  {{i18n
                    "admin.dashboard.site_traffic.details.dimensions.pages"
                  }}
                </h2>
                {{#if this.pageCardInformational}}
                  <span>
                    {{i18n
                      "admin.dashboard.site_traffic.details.overall_analyzed_period"
                    }}
                  </span>
                {{/if}}
              </div>
              <div
                class="site-traffic-detail__tabs"
                role="tablist"
                aria-label={{i18n
                  "admin.dashboard.site_traffic.details.dimensions.pages"
                }}
              >
                <button
                  id="site-traffic-tab-top-urls"
                  type="button"
                  role="tab"
                  data-site-traffic-tab="top_urls"
                  aria-controls="site-traffic-pages-panel"
                  aria-selected={{concat
                    (if (eq this.pagesTab "top_urls") "true" "false")
                  }}
                  tabindex={{if (eq this.pagesTab "top_urls") "0" "-1"}}
                  class={{if (eq this.pagesTab "top_urls") "is-active"}}
                  {{on "click" (fn this.selectPagesTab "top_urls")}}
                  {{on "keydown" this.navigatePagesTabs}}
                >
                  {{i18n
                    "admin.dashboard.site_traffic.details.dimensions.top_urls"
                  }}
                </button>
                <button
                  id="site-traffic-tab-entry-urls"
                  type="button"
                  role="tab"
                  data-site-traffic-tab="entry_urls"
                  aria-controls="site-traffic-pages-panel"
                  aria-selected={{concat
                    (if (eq this.pagesTab "entry_urls") "true" "false")
                  }}
                  tabindex={{if (eq this.pagesTab "entry_urls") "0" "-1"}}
                  class={{if (eq this.pagesTab "entry_urls") "is-active"}}
                  {{on "click" (fn this.selectPagesTab "entry_urls")}}
                  {{on "keydown" this.navigatePagesTabs}}
                >
                  {{i18n
                    "admin.dashboard.site_traffic.details.dimensions.entry_urls"
                  }}
                </button>
              </div>
              <div
                id="site-traffic-pages-panel"
                role="tabpanel"
                aria-labelledby={{if
                  (eq this.pagesTab "top_urls")
                  "site-traffic-tab-top-urls"
                  "site-traffic-tab-entry-urls"
                }}
              >
                <ul class="site-traffic-detail__breakdown-list">
                  {{#each (this.cardRows this.pageRows) as |row|}}
                    <li>
                      {{#if row.filterable}}
                        <button
                          type="button"
                          class="btn-flat site-traffic-detail__row"
                          data-test-breakdown-row
                          {{on "click" (fn this.applyFilter "url" row.value)}}
                        >
                          <span>{{row.displayLabel}}</span>
                          <strong>{{row.formattedPageviews}}</strong>
                        </button>
                      {{else}}
                        <span
                          class="site-traffic-detail__row"
                          data-test-breakdown-row
                        >
                          <span>{{row.displayLabel}}</span>
                          <strong>{{row.formattedPageviews}}</strong>
                        </span>
                      {{/if}}
                    </li>
                  {{/each}}
                </ul>
                {{#if (gt this.pageRows.length 8)}}
                  <DButton
                    @label="admin.dashboard.site_traffic.details.view_more"
                    @action={{fn
                      this.showMore
                      this.pagesTab
                      this.pageCardTitle
                      this.pageRows
                    }}
                  />
                {{/if}}
              </div>
            </section>

            <section
              class="site-traffic-detail__card"
              data-test-breakdown="geography"
            >
              <div class="site-traffic-detail__card-header">
                <h2>
                  {{i18n
                    "admin.dashboard.site_traffic.details.dimensions.geography"
                  }}
                </h2>
              </div>
              <div
                class="site-traffic-detail__tabs"
                role="tablist"
                aria-label={{i18n
                  "admin.dashboard.site_traffic.details.dimensions.geography"
                }}
              >
                {{#each (array "countries" "networks" "ip_addresses") as |tab|}}
                  <button
                    id="site-traffic-geography-tab-{{tab}}"
                    type="button"
                    role="tab"
                    data-site-traffic-geography-tab={{tab}}
                    aria-controls="site-traffic-geography-panel"
                    aria-selected={{concat
                      (if (eq this.geographyTab tab) "true" "false")
                    }}
                    tabindex={{if (eq this.geographyTab tab) "0" "-1"}}
                    class={{if (eq this.geographyTab tab) "is-active"}}
                    {{on "click" (fn this.selectGeographyTab tab)}}
                    {{on "keydown" this.navigateGeographyTabs}}
                  >
                    {{i18n
                      (concat
                        "admin.dashboard.site_traffic.details.dimensions." tab
                      )
                    }}
                  </button>
                {{/each}}
              </div>
              <div
                id="site-traffic-geography-panel"
                role="tabpanel"
                aria-labelledby="site-traffic-geography-tab-{{this.geographyTab}}"
              >
                <ul class="site-traffic-detail__breakdown-list">
                  {{#each (this.cardRows this.geographyRows) as |row|}}
                    <li>
                      {{#if row.filterable}}
                        <button
                          type="button"
                          class="btn-flat site-traffic-detail__row"
                          data-test-breakdown-row
                          {{on
                            "click"
                            (fn
                              this.applyFilter
                              (get FILTER_DIMENSIONS this.geographyTab)
                              row.value
                            )
                          }}
                        >
                          <span>
                            {{#if (eq this.geographyTab "countries")}}
                              <span aria-hidden="true">
                                {{this.countryFlag row.value}}
                              </span>
                            {{/if}}
                            {{row.displayLabel}}
                          </span>
                          <strong>{{row.formattedPageviews}}</strong>
                        </button>
                      {{else}}
                        <span
                          class="site-traffic-detail__row"
                          data-test-breakdown-row
                        >
                          <span>{{row.displayLabel}}</span>
                          <strong>{{row.formattedPageviews}}</strong>
                        </span>
                      {{/if}}
                    </li>
                  {{/each}}
                </ul>
                {{#if (gt this.geographyRows.length 8)}}
                  <DButton
                    @label="admin.dashboard.site_traffic.details.view_more"
                    @action={{fn
                      this.showMore
                      this.geographyTab
                      this.geographyCardTitle
                      this.geographyRows
                    }}
                  />
                {{/if}}
              </div>
            </section>

            <section
              class="site-traffic-detail__card"
              data-test-breakdown={{this.browsersCard.key}}
            >
              <div class="site-traffic-detail__card-header">
                <h2>{{this.browsersCard.title}}</h2>
              </div>
              <ul class="site-traffic-detail__breakdown-list">
                {{#each (this.cardRows this.browsersCard.rows) as |row|}}
                  <li>
                    {{#if row.filterable}}
                      <button
                        type="button"
                        class="btn-flat site-traffic-detail__row"
                        data-test-breakdown-row
                        {{on "click" (fn this.applyFilter "browser" row.value)}}
                      >
                        <span>{{row.displayLabel}}</span>
                        <strong>{{row.formattedPageviews}}</strong>
                      </button>
                    {{else}}
                      <span
                        class="site-traffic-detail__row"
                        data-test-breakdown-row
                      >
                        <span>{{row.displayLabel}}</span>
                        <strong>{{row.formattedPageviews}}</strong>
                      </span>
                    {{/if}}
                  </li>
                {{/each}}
              </ul>
              {{#if (gt this.browsersCard.rows.length 8)}}
                <DButton
                  @label="admin.dashboard.site_traffic.details.view_more"
                  @action={{fn
                    this.showMore
                    this.browsersCard.key
                    this.browsersCard.title
                    this.browsersCard.rows
                  }}
                />
              {{/if}}
            </section>
          </div>
        {{/if}}
      {{/if}}
    </main>
  </template>
}
