import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import SiteTrafficBreakdownCard from "discourse/admin/components/dashboard/site-traffic-breakdown-card";
import SiteTrafficMetric from "discourse/admin/components/dashboard/site-traffic-metric";
import SiteTrafficBreakdownModal from "discourse/admin/components/modal/site-traffic-breakdown";
import { countryName } from "discourse/admin/lib/format-country";
import {
  SITE_TRAFFIC_BROWSER_FAMILIES,
  SITE_TRAFFIC_SAFE_FILTERS,
  validSiteTrafficSafeFilter,
} from "discourse/admin/lib/site-traffic-filters";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import { formatMinutesSeconds } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import Session from "discourse/models/session";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import I18n, { i18n } from "discourse-i18n";

const SENSITIVE_FILTERS = new Set(["top_url", "entry_url", "referrer", "ip"]);
const FILTER_OPTION_LIMIT = 20;
const BROWSER_ICONS = {
  edge: "fab-edge",
  opera: "fab-opera",
  firefox: "fab-firefox-browser",
  chrome: "fab-chrome",
  safari: "fab-safari",
  ie: "fab-internet-explorer",
  discoursehub: "fab-discourse",
  unknown: "globe",
};
const FILTER_DIMENSIONS = {
  top_urls: "top_url",
  entry_urls: "entry_url",
  traffic_sources: "referrer",
  countries: "country",
  networks: "asn",
  browsers: "browser",
  ip_addresses: "ip",
};
const FILTER_SOURCE_DIMENSIONS = {
  top_url: "top_urls",
  entry_url: "entry_urls",
  referrer: "traffic_sources",
  country: "countries",
  asn: "networks",
  browser: "browsers",
  ip: "ip_addresses",
};
const FILTER_PREFIXES = {
  top_url: "top_url",
  entry_url: "entry_url",
  referrer: "referrer",
  country: "country",
  asn: "network",
  browser: "browser",
  ip: "ip",
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
const SKELETON_KPIS = Array.from({ length: 5 });
const SKELETON_CARDS = Array.from({ length: 3 });
const SKELETON_ROWS = Array.from({ length: 5 });

export default class SiteTrafficDetail extends Component {
  @service currentUser;
  @service modal;
  @service sessionStore;

  @tracked data;
  @tracked loading = false;
  @tracked error;
  @tracked filters = {};
  @tracked suggestionDimension;
  @tracked sourceTab = "traffic_sources";
  @tracked pagesTab = "top_urls";
  @tracked visitorTab = "browsers";

  abortController;
  requestId = 0;
  chartOptions = { hideYAxisGridLines: true, hiddenLabels: [] };

  constructor() {
    super(...arguments);
    this.filters = {
      ...this.#safeFiltersFromArgs(),
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

  get formattedLoggedInShare() {
    if (!this.summary.pageviews) {
      return "—";
    }

    const share =
      (this.summary.logged_in_human_pageviews * 100) / this.summary.pageviews;
    return `${I18n.toNumber(share, { precision: 0 })}%`;
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

  get filterOptions() {
    return Object.entries(FILTER_SOURCE_DIMENSIONS).flatMap(
      ([dimension, sourceDimension]) =>
        (this.dimensions[sourceDimension] || [])
          .filter((row) => row.filterable)
          .map((row) => ({
            id: `${dimension}:${row.value}`,
            dimension,
            value: row.value,
            name: this.#rowLabel(sourceDimension, row),
            expression: this.#filterExpression(dimension, row.value),
          }))
    );
  }

  get filterInputValue() {
    return Object.keys(FILTER_SOURCE_DIMENSIONS)
      .filter((dimension) => this.filters[dimension])
      .map((dimension) =>
        this.#filterExpression(dimension, this.filters[dimension])
      )
      .join(" ");
  }

  get breakdownCards() {
    return [
      {
        key: "sources",
        title: i18n("admin.dashboard.site_traffic.details.dimensions.sources"),
        tabs: [
          {
            key: "traffic_sources",
            label: i18n(
              "admin.dashboard.site_traffic.details.dimensions.traffic_sources"
            ),
          },
          {
            key: "countries",
            label: i18n(
              "admin.dashboard.site_traffic.details.dimensions.countries"
            ),
          },
          {
            key: "networks",
            label: i18n(
              "admin.dashboard.site_traffic.details.dimensions.networks"
            ),
          },
        ],
        activeTab: this.sourceTab,
        rows: this.#displayRows(this.sourceTab),
        filterDimension: FILTER_DIMENSIONS[this.sourceTab],
      },
      {
        key: "pages",
        title: i18n("admin.dashboard.site_traffic.details.dimensions.pages"),
        tabs: [
          {
            key: "top_urls",
            label: i18n(
              "admin.dashboard.site_traffic.details.dimensions.top_urls"
            ),
          },
          {
            key: "entry_urls",
            label: i18n(
              "admin.dashboard.site_traffic.details.dimensions.entry_urls"
            ),
          },
        ],
        activeTab: this.pagesTab,
        rows: this.#displayRows(this.pagesTab),
        filterDimension: FILTER_DIMENSIONS[this.pagesTab],
      },
      {
        key: "visitors",
        title: i18n(
          "admin.dashboard.site_traffic.details.dimensions.visitor_dimensions"
        ),
        tabs: [
          {
            key: "browsers",
            label: i18n(
              "admin.dashboard.site_traffic.details.dimensions.browsers"
            ),
          },
          {
            key: "ip_addresses",
            label: i18n(
              "admin.dashboard.site_traffic.details.dimensions.ip_addresses"
            ),
          },
        ],
        activeTab: this.visitorTab,
        rows: this.#displayRows(this.visitorTab),
        filterDimension: FILTER_DIMENSIONS[this.visitorTab],
      },
    ];
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
    this.suggestionDimension = null;
    this.#updateFilters({ ...this.filters, [dimension]: value });
  }

  @action
  filterInputChanged(value, submit) {
    if (!submit) {
      const dimension = Object.keys(FILTER_SOURCE_DIMENSIONS).find(
        (candidate) => value === this.#filterPrefix(candidate)
      );
      if (dimension) {
        this.suggestionDimension = dimension;
      } else if (
        !this.suggestionDimension ||
        !value.startsWith(this.#filterPrefix(this.suggestionDimension))
      ) {
        this.suggestionDimension = null;
      }
      return;
    }

    if (!value) {
      this.suggestionDimension = null;
      this.#updateFilters({});
      return;
    }

    const option = this.filterOptions.find(
      (candidate) =>
        candidate.dimension === this.suggestionDimension &&
        candidate.expression === value
    );
    this.suggestionDimension = null;

    if (option) {
      this.#updateFilters({
        ...this.filters,
        [option.dimension]: option.value,
      });
    }
  }

  @action
  async getFilterSuggestions(input) {
    if (!this.suggestionDimension) {
      return {
        suggestions: Object.keys(FILTER_SOURCE_DIMENSIONS).map((dimension) => ({
          name: i18n(
            `admin.dashboard.site_traffic.details.filter_dimensions.${dimension}`
          ),
          inputValue: this.#filterPrefix(dimension),
        })),
      };
    }

    const prefix = this.#filterPrefix(this.suggestionDimension);
    const query = input.startsWith(prefix)
      ? input.slice(prefix.length).trim().toLocaleLowerCase()
      : "";

    return {
      suggestions: this.filterOptions
        .filter(
          (option) =>
            option.dimension === this.suggestionDimension &&
            option.name.toLocaleLowerCase().includes(query)
        )
        .slice(0, FILTER_OPTION_LIMIT)
        .map((option) => ({
          ...option,
          inputValue: option.expression,
          submitOnSelect: true,
        })),
    };
  }

  @action
  safeFiltersChanged() {
    const safeFilters = this.#safeFiltersFromArgs();
    const currentSafeFilters = Object.fromEntries(
      Object.entries(this.filters).filter(([key]) =>
        SITE_TRAFFIC_SAFE_FILTERS.includes(key)
      )
    );

    if (
      SITE_TRAFFIC_SAFE_FILTERS.every(
        (key) => safeFilters[key] === currentSafeFilters[key]
      )
    ) {
      return;
    }

    this.filters = {
      ...Object.fromEntries(
        Object.entries(this.filters).filter(
          ([key]) => !SITE_TRAFFIC_SAFE_FILTERS.includes(key)
        )
      ),
      ...safeFilters,
    };
    this.load();
  }

  @action
  selectBreakdownTab(cardKey, tabKey) {
    if (cardKey === "sources") {
      this.sourceTab = tabKey;
    } else if (cardKey === "pages") {
      this.pagesTab = tabKey;
    } else if (cardKey === "visitors") {
      this.visitorTab = tabKey;
    }
  }

  @action
  showMore(dimension, title, rows) {
    this.modal.show(SiteTrafficBreakdownModal, {
      model: {
        title,
        rows,
        dimension,
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
      icon: dimension === "browsers" ? this.#browserIcon(row.value) : null,
      formattedPageviews: this.#formatNumber(row.pageviews),
    }));
  }

  #browserIcon(value) {
    return BROWSER_ICONS[
      SITE_TRAFFIC_BROWSER_FAMILIES.has(value) ? value : "unknown"
    ];
  }

  #rowLabel(dimension, row) {
    if (dimension === "countries") {
      return countryName(row.value) || row.label;
    }

    if (dimension === "browsers") {
      return i18n(
        `admin.dashboard.site_traffic.details.browsers.${
          SITE_TRAFFIC_BROWSER_FAMILIES.has(row.value) ? row.value : "unknown"
        }`
      );
    }

    return row.label;
  }

  #filterExpression(dimension, value) {
    return `${FILTER_PREFIXES[dimension]}:${value}`;
  }

  #filterPrefix(dimension) {
    return `${FILTER_PREFIXES[dimension]}:`;
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

  #safeFiltersFromArgs() {
    return Object.fromEntries(
      SITE_TRAFFIC_SAFE_FILTERS.flatMap((key) => {
        const value = this.args[key];
        return validSiteTrafficSafeFilter(key, value) ? [[key, value]] : [];
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

  #updateFilters(filters) {
    this.filters = filters;
    this.args.setSafeFilters?.(
      Object.fromEntries(
        SITE_TRAFFIC_SAFE_FILTERS.map((key) => [key, this.filters[key] || null])
      )
    );
    this.#persistSensitiveFilters();
    this.load();
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
      {{didUpdate this.safeFiltersChanged @country @asn @browser}}
    >
      <div class="site-traffic-detail__sticky-controls">
        <div
          class="site-traffic-detail__filters"
          aria-label={{i18n
            "admin.dashboard.site_traffic.details.active_filters"
          }}
        >
          <div
            class="site-traffic-detail__filter-control"
            data-test-filter-control
          >
            <FilterNavigationMenu
              @getSuggestions={{this.getFilterSuggestions}}
              @initialInputValue={{this.filterInputValue}}
              @onChange={{this.filterInputChanged}}
              @menuClass="site-traffic-filter-menu"
              @placeholder={{i18n
                "admin.dashboard.site_traffic.details.filter_placeholder"
              }}
            />
          </div>
        </div>

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
          aria-labelledby="site-traffic-metrics"
        >
          <h2 id="site-traffic-metrics" class="sr-only">
            {{i18n "admin.dashboard.site_traffic.details.traffic_metrics"}}
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
              "admin.dashboard.site_traffic.details.kpi.distinct_sessions.label"
            }}
            @value={{this.formattedDistinctSessions}}
            @tooltip={{i18n
              "admin.dashboard.site_traffic.details.kpi.distinct_sessions.tooltip"
            }}
            @tooltipIdentifier="site-traffic-detail-sessions-tooltip"
            data-test-metric
            data-test-session-kpi
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.kpi.logged_in_share.label"
            }}
            @value={{this.formattedLoggedInShare}}
            @tooltip={{i18n
              "admin.dashboard.site_traffic.details.kpi.logged_in_share.tooltip"
            }}
            @tooltipIdentifier="site-traffic-detail-logged-in-share-tooltip"
            data-test-metric
            data-test-logged-in-share
          />
          <SiteTrafficMetric
            @label={{i18n
              "admin.dashboard.site_traffic.details.kpi.bounce_rate.label"
            }}
            @value={{this.formattedBounceRate}}
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
          <span
            class="sr-only"
            data-test-series-total
            data-test-traffic-series="logged-in-human"
          >{{i18n
              "admin.dashboard.site_traffic.details.series.logged-in-human"
            }}
            {{this.formattedLoggedInHumanPageviews}}</span>
          <span
            class="sr-only"
            data-test-series-total
            data-test-traffic-series="anonymous-human"
          >{{i18n
              "admin.dashboard.site_traffic.details.series.anonymous-human"
            }}
            {{this.formattedAnonymousHumanPageviews}}</span>
          <span
            class="sr-only"
            data-test-series-total
            data-test-traffic-series="likely-crawler"
          >{{i18n "admin.dashboard.site_traffic.details.series.likely-crawler"}}
            {{this.formattedLikelyCrawlerPageviews}}</span>
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
            {{#each this.breakdownCards as |card|}}
              <SiteTrafficBreakdownCard
                @cardKey={{card.key}}
                @title={{card.title}}
                @tabs={{card.tabs}}
                @activeTab={{card.activeTab}}
                @rows={{card.rows}}
                @filterDimension={{card.filterDimension}}
                @onSelectTab={{fn this.selectBreakdownTab card.key}}
                @onApplyFilter={{this.applyFilter}}
                @onViewMore={{this.showMore}}
              />
            {{/each}}
          </div>
        {{/if}}
      {{/if}}
    </main>
  </template>
}
