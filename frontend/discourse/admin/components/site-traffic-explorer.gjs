import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import SiteTrafficExplorerBreakdownCard from "discourse/admin/components/site-traffic-explorer-breakdown-card";
import SiteTrafficExplorerFilterPills from "discourse/admin/components/site-traffic-explorer-filter-pills";
import SiteTrafficExplorerMetric from "discourse/admin/components/site-traffic-explorer-metric";
import { formatPageviewCount } from "discourse/admin/lib/format-pageview-count";
import { formatMinutesSeconds } from "discourse/lib/formatter";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import I18n, { i18n } from "discourse-i18n";

const SKELETON_METRICS = Array.from({ length: 4 });
const SKELETON_BREAKDOWNS = Array.from({ length: 3 });
const SKELETON_ROWS = Array.from({ length: 5 });
const TRAFFIC_TYPE_BY_SERIES = {
  page_view_logged_in_browser: "logged_in",
  page_view_anon_browser: "anonymous",
  page_view_likely_crawler: "likely_crawler",
};

export default class SiteTrafficExplorer extends Component {
  @service a11y;
  @service siteSettings;

  get summary() {
    return this.args.traffic?.summary ?? {};
  }

  get metrics() {
    return [
      {
        name: "distinct_sessions",
        label: i18n(
          "admin.site_traffic_explorer.metrics.distinct_sessions.label"
        ),
        value: this.#number(this.summary.distinct_sessions),
      },
      {
        name: "logged_in_share",
        label: i18n(
          "admin.site_traffic_explorer.metrics.logged_in_share.label"
        ),
        tooltip: i18n(
          "admin.dashboard.site_traffic.kpi.logged_in_share.tooltip"
        ),
        value: `${this.#number(this.summary.logged_in_share)}%`,
      },
      {
        name: "bounce_rate",
        label: i18n("admin.site_traffic_explorer.metrics.bounce_rate.label"),
        tooltip: i18n("admin.dashboard.site_traffic.kpi.bounce_rate.tooltip"),
        value: `${this.#number(this.summary.bounce_rate)}%`,
      },
      {
        name: "average_session_duration",
        label: i18n(
          "admin.site_traffic_explorer.metrics.average_session_duration.label"
        ),
        tooltip: i18n(
          "admin.dashboard.site_traffic.kpi.average_session_duration.tooltip"
        ),
        value: formatMinutesSeconds(
          this.summary.average_session_duration_seconds ?? 0,
          { subsecondPrecision: 2 }
        ),
      },
    ];
  }

  get headlineText() {
    const count = this.summary.pageviews ?? 0;

    return i18n("admin.site_traffic_explorer.headline", {
      count,
      formatted_count: formatPageviewCount(count),
    });
  }

  @cached
  get chartModel() {
    return {
      start_date:
        this.args.traffic?.chart_start_date ??
        moment(this.args.startDate).format("YYYY-MM-DD"),
      end_date:
        this.args.traffic?.chart_end_date ??
        moment(this.args.endDate).format("YYYY-MM-DD"),
      data: this.series,
    };
  }

  @cached
  get chartOptions() {
    return {
      hideYAxisGridLines: true,
      hiddenLabels: Object.entries(TRAFFIC_TYPE_BY_SERIES)
        .filter(
          ([, trafficType]) => !this.args.trafficTypes.includes(trafficType)
        )
        .map(([series]) => series),
      onLegendClick: this.toggleTrafficType,
    };
  }

  get series() {
    const rows = this.args.traffic?.series ?? [];
    const series = [
      {
        key: "logged-in-human",
        column: "logged_in_human_pageviews",
        req: "page_view_logged_in_browser",
        label: i18n("admin.site_traffic_explorer.series.logged_in_human"),
        color: this.args.traffic?.series_colors?.logged_in_human_pageviews,
      },
      {
        key: "anonymous-human",
        column: "anonymous_human_pageviews",
        req: "page_view_anon_browser",
        label: i18n("admin.site_traffic_explorer.series.anonymous_human"),
        color: this.args.traffic?.series_colors?.anonymous_human_pageviews,
      },
    ];

    if (this.siteSettings.improved_crawler_detection) {
      series.push({
        key: "likely-crawler",
        column: "likely_crawler_pageviews",
        req: "page_view_likely_crawler",
        label: i18n("admin.site_traffic_explorer.series.likely_crawler"),
        color: this.args.traffic?.series_colors?.likely_crawler_pageviews,
      });
    }

    return series.map((item) => ({
      ...item,
      total: rows.reduce((sum, row) => sum + (row[item.column] ?? 0), 0),
      data: rows.map((row) => ({ x: row.date, y: row[item.column] ?? 0 })),
    }));
  }

  get acquisitionTabs() {
    return [
      this.#tab({ dimension: "referrers", filter: "referrer" }),
      this.#tab({ dimension: "countries", filter: "country" }),
      this.#tab({ dimension: "networks", filter: "network" }),
    ];
  }

  get pagesTabs() {
    return [
      this.#tab({ dimension: "top_urls", filter: "top_url" }),
      this.#tab({ dimension: "entry_urls", filter: "entry_url" }),
    ];
  }

  get visitorsTabs() {
    return [
      this.#tab({ dimension: "browsers", filter: "browser" }),
      this.#tab({ dimension: "languages", filter: "language" }),
      this.#tab({ dimension: "ip_addresses", filter: "ip" }),
    ];
  }

  get partialWarning() {
    const partial = this.args.traffic?.partial_data;
    if (!partial) {
      return null;
    }

    const availableDate = partial.available_start_date
      ? moment(partial.available_start_date).format("ll")
      : null;

    const pageviewLimitStart = moment.utc(partial.pageview_limit_start_at);
    const pageviewLimitDate = pageviewLimitStart.format("ll");
    const pageviewLimitTime = pageviewLimitStart.format("LT");

    if (partial.reason === "retention_and_pageview_limit") {
      return i18n("admin.site_traffic_explorer.partial.combined", {
        date: availableDate,
        limit: this.#number(partial.pageview_limit),
        pageviewLimitDate,
        pageviewLimitTime,
      });
    }
    if (partial.reason === "retention") {
      return i18n("admin.site_traffic_explorer.partial.retention", {
        date: availableDate,
      });
    }
    return i18n("admin.site_traffic_explorer.partial.pageview_limit", {
      limit: this.#number(partial.pageview_limit),
      date: pageviewLimitDate,
      time: pageviewLimitTime,
    });
  }

  get fetchErrorMessage() {
    return i18n(
      `admin.site_traffic_explorer.errors.${this.args.fetchError ?? "unexpected"}`
    );
  }

  @action
  announceResults() {
    if (this.args.loading || !this.args.traffic) {
      return;
    }

    if (this.partialWarning) {
      this.a11y.announce(this.partialWarning, "polite");
    } else if (!this.args.hasPageviews) {
      this.a11y.announce(i18n("admin.site_traffic_explorer.empty"), "polite");
    }
  }

  @action
  toggleTrafficType(series) {
    this.args.toggleTrafficType(TRAFFIC_TYPE_BY_SERIES[series]);
  }

  #number(value) {
    return I18n.toNumber(value ?? 0, { precision: 0 });
  }

  #tab({ dimension, filter }) {
    return {
      dimension,
      filter,
      label: i18n(`admin.site_traffic_explorer.dimensions.${dimension}`),
    };
  }

  <template>
    <div
      class="admin-config-page"
      {{didUpdate this.announceResults @traffic @loading @hasPageviews}}
    >
      <DPageHeader
        @titleLabel={{i18n "admin.site_traffic_explorer.title"}}
        @hideTabs={{true}}
        @collapseActionsOnMobile={{false}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin"
            @label={{i18n "admin.dashboard.title"}}
          />
          <DBreadcrumbsItem
            @path="/admin/dashboard/site-traffic-explorer"
            @label={{i18n "admin.site_traffic_explorer.title"}}
          />
        </:breadcrumbs>
        <:actions>
          <DashboardDateRange
            @period={{@period}}
            @startDate={{@startDate}}
            @endDate={{@endDate}}
            @setPeriod={{@setPeriod}}
            @setCustomDateRange={{@setCustomDateRange}}
          />
        </:actions>
      </DPageHeader>

      <div class="admin-container site-traffic-explorer">
        <SiteTrafficExplorerFilterPills
          @filters={{@activeFilters}}
          @hasPendingFilters={{@hasPendingFilters}}
          @pendingFilterCount={{@pendingFilterCount}}
          @removeFilterValue={{@removeFilterValue}}
          @clearFilter={{@clearFilter}}
          @clearAllFilters={{@clearAllFilters}}
          @applyFilters={{@applyFilters}}
        />

        {{#if @fetchError}}
          <div class="db-section__wrapper --column">
            <div class="db-section__traffic-chart site-traffic-explorer__chart">
              <div class="db-section__traffic-chart-message" role="alert">
                {{this.fetchErrorMessage}}
              </div>
            </div>
          </div>
        {{else}}
          {{#if @loading}}
            <div
              class="db-skeleton --animation site-traffic-explorer__skeleton"
              role="status"
              aria-label={{i18n "admin.site_traffic_explorer.loading"}}
              data-test-site-traffic-skeleton
            >
              <div class="db-skeleton__section-wrapper">
                <div class="db-skeleton__subheader">
                  <div class="db-skeleton__subintro">
                    <div class="db-skeleton__heading-line"></div>
                  </div>
                  <div class="db-skeleton__metric-row">
                    {{#each SKELETON_METRICS}}
                      <div class="db-skeleton__metric">
                        <div class="db-skeleton__metric-number"></div>
                        <div class="db-skeleton__metric-label"></div>
                      </div>
                    {{/each}}
                  </div>
                </div>
                <div class="db-skeleton__chart"></div>
                <div class="db-skeleton__row">
                  {{#each SKELETON_BREAKDOWNS}}
                    <div class="db-skeleton__row-block">
                      <div class="db-skeleton__row-block-title"></div>
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
            </div>
          {{else if this.partialWarning}}
            <p
              class="alert alert-warning site-traffic-explorer__partial-warning"
              data-test-site-traffic-partial-warning
              data-test-partial-reason
            >
              {{this.partialWarning}}
            </p>
          {{/if}}

          {{#if @traffic}}

            {{#if @hasPageviews}}
              <div class="db-section__wrapper --column" hidden={{@loading}}>
                <section class="db-section__subheader">
                  <div class="db-section__subintro">
                    <h3>{{this.headlineText}}</h3>
                  </div>

                  <div class="db-section__metrics">
                    {{#each this.metrics as |metric|}}
                      <SiteTrafficExplorerMetric
                        @name={{metric.name}}
                        @label={{metric.label}}
                        @tooltip={{metric.tooltip}}
                        @value={{metric.value}}
                      />
                    {{/each}}
                  </div>
                </section>

                <div class="db-section__traffic-chart">
                  <AdminReportStackedChart
                    @model={{this.chartModel}}
                    @options={{this.chartOptions}}
                    class="db-section__traffic-chart-canvas"
                  />
                  <div class="sr-only">
                    {{#each this.series as |series|}}
                      <span
                        data-test-traffic-series={{series.key}}
                      >{{series.total}}</span>
                    {{/each}}
                  </div>
                </div>

                <div class="db-section__row">
                  <SiteTrafficExplorerBreakdownCard
                    @name="acquisition"
                    @title={{i18n
                      "admin.site_traffic_explorer.cards.acquisition"
                    }}
                    @tabs={{this.acquisitionTabs}}
                    @dimensions={{@traffic.dimensions}}
                    @isFilterSelected={{@isFilterSelected}}
                    @toggleFilter={{@toggleFilter}}
                    @applyModalFilters={{@applyModalFilters}}
                  />
                  <SiteTrafficExplorerBreakdownCard
                    @name="pages"
                    @title={{i18n "admin.site_traffic_explorer.cards.pages"}}
                    @tabs={{this.pagesTabs}}
                    @dimensions={{@traffic.dimensions}}
                    @isFilterSelected={{@isFilterSelected}}
                    @toggleFilter={{@toggleFilter}}
                    @applyModalFilters={{@applyModalFilters}}
                  />
                  <SiteTrafficExplorerBreakdownCard
                    @name="visitors"
                    @title={{i18n "admin.site_traffic_explorer.cards.visitors"}}
                    @tabs={{this.visitorsTabs}}
                    @dimensions={{@traffic.dimensions}}
                    @isFilterSelected={{@isFilterSelected}}
                    @toggleFilter={{@toggleFilter}}
                    @applyModalFilters={{@applyModalFilters}}
                  />
                </div>
              </div>
            {{else}}
              <div
                class="site-traffic-explorer__empty"
                data-test-site-traffic-empty
              >
                {{i18n "admin.site_traffic_explorer.empty"}}
              </div>
            {{/if}}

          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
