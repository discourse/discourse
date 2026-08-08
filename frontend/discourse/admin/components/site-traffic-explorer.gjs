import Component from "@glimmer/component";
import { service } from "@ember/service";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import SiteTrafficBreakdownCard from "discourse/admin/components/site-traffic-breakdown-card";
import SiteTrafficFilterPills from "discourse/admin/components/site-traffic-filter-pills";
import SiteTrafficMetric from "discourse/admin/components/site-traffic-metric";
import { formatMinutesSeconds } from "discourse/lib/formatter";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DPageHeader from "discourse/ui-kit/d-page-header";
import I18n, { i18n } from "discourse-i18n";

export default class SiteTrafficExplorer extends Component {
  @service siteSettings;

  get summary() {
    return this.args.traffic?.summary ?? {};
  }

  get metrics() {
    return [
      {
        name: "pageviews",
        label: i18n("admin.site_traffic_explorer.metrics.pageviews.label"),
        tooltip: i18n("admin.site_traffic_explorer.metrics.pageviews.tooltip"),
        value: this.#number(this.summary.pageviews),
      },
      {
        name: "distinct_sessions",
        label: i18n(
          "admin.site_traffic_explorer.metrics.distinct_sessions.label"
        ),
        tooltip: i18n(
          "admin.site_traffic_explorer.metrics.distinct_sessions.tooltip"
        ),
        value: this.#number(this.summary.distinct_sessions),
      },
      {
        name: "logged_in_share",
        label: i18n(
          "admin.site_traffic_explorer.metrics.logged_in_share.label"
        ),
        tooltip: i18n(
          "admin.site_traffic_explorer.metrics.logged_in_share.tooltip"
        ),
        value: `${this.#number(this.summary.logged_in_share)}%`,
      },
      {
        name: "bounce_rate",
        label: i18n("admin.site_traffic_explorer.metrics.bounce_rate.label"),
        tooltip: i18n(
          "admin.site_traffic_explorer.metrics.bounce_rate.tooltip"
        ),
        value: `${this.#number(this.summary.bounce_rate)}%`,
      },
      {
        name: "average_session_duration",
        label: i18n(
          "admin.site_traffic_explorer.metrics.average_session_duration.label"
        ),
        tooltip: i18n(
          "admin.site_traffic_explorer.metrics.average_session_duration.tooltip"
        ),
        value: formatMinutesSeconds(
          this.summary.average_session_duration_seconds ?? 0
        ),
      },
    ];
  }

  get chartModel() {
    return {
      start_date: moment(this.args.startDate).format("YYYY-MM-DD"),
      end_date: moment(this.args.endDate).format("YYYY-MM-DD"),
      data: this.series,
    };
  }

  get chartOptions() {
    return { hideYAxisGridLines: true };
  }

  get series() {
    const rows = this.args.traffic?.series ?? [];
    const series = [
      {
        key: "logged-in-human",
        column: "logged_in_human_pageviews",
        req: "page_view_logged_in_browser",
        label: i18n("admin.site_traffic_explorer.series.logged_in_human"),
      },
      {
        key: "anonymous-human",
        column: "anonymous_human_pageviews",
        req: "page_view_anon_browser",
        label: i18n("admin.site_traffic_explorer.series.anonymous_human"),
      },
    ];

    if (this.siteSettings.improved_crawler_detection) {
      series.push({
        key: "likely-crawler",
        column: "likely_crawler_pageviews",
        req: "page_view_likely_crawler",
        label: i18n("admin.site_traffic_explorer.series.likely_crawler"),
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
      this.#tab("referrers", "referrer"),
      this.#tab("countries", "country"),
      this.#tab("networks", "network"),
    ];
  }

  get pagesTabs() {
    return [
      this.#tab("top_urls", "top_url", true),
      this.#tab("entry_urls", "entry_url", true),
    ];
  }

  get visitorsTabs() {
    return [this.#tab("browsers", "browser"), this.#tab("ip_addresses", "ip")];
  }

  get partialWarning() {
    const partial = this.args.traffic?.partial_data;
    if (!partial) {
      return null;
    }

    const availableDate = partial.available_start_date
      ? moment(partial.available_start_date).format("ll")
      : null;

    if (partial.reason === "retention_and_pageview_limit") {
      return i18n("admin.site_traffic_explorer.partial.combined", {
        date: availableDate,
        limit: this.#number(partial.pageview_limit),
      });
    }
    if (partial.reason === "retention") {
      return i18n("admin.site_traffic_explorer.partial.retention", {
        date: availableDate,
      });
    }
    return i18n("admin.site_traffic_explorer.partial.pageview_limit", {
      limit: this.#number(partial.pageview_limit),
    });
  }

  get fetchErrorMessage() {
    return i18n(
      `admin.site_traffic_explorer.errors.${this.args.fetchError ?? "unexpected"}`
    );
  }

  #number(value) {
    return I18n.toNumber(value ?? 0, { precision: 0 });
  }

  #tab(dimension, filter, link = false) {
    return {
      dimension,
      filter,
      link,
      label: i18n(`admin.site_traffic_explorer.dimensions.${dimension}`),
    };
  }

  <template>
    <div class="site-traffic-explorer admin-config-page">
      <DPageHeader
        @titleLabel={{i18n "admin.site_traffic_explorer.title"}}
        @descriptionLabel={{i18n "admin.site_traffic_explorer.description"}}
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
            @path="/admin/dashboard/traffic"
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

      <div class="admin-container site-traffic-explorer__content">
        <SiteTrafficFilterPills
          @filters={{@activeFilters}}
          @removeFilter={{@removeFilter}}
          @clearFilters={{@clearFilters}}
        />

        {{#if @fetchError}}
          <div class="site-traffic-explorer__error" role="alert">
            <p>{{this.fetchErrorMessage}}</p>
            <DButton
              @action={{@retry}}
              @label="admin.site_traffic_explorer.retry"
              class="btn-primary"
            />
          </div>
        {{else}}
          {{#if @loading}}
            <div
              class="site-traffic-explorer__loading"
              role="status"
              aria-live="polite"
              aria-busy="true"
            >
              {{i18n "admin.site_traffic_explorer.loading"}}
            </div>
          {{else if this.partialWarning}}
            <div
              class="alert alert-warning site-traffic-explorer__partial-warning"
              role="status"
              aria-live="polite"
              data-test-site-traffic-partial-warning
            >
              <strong>{{i18n
                  "admin.site_traffic_explorer.partial.title"
                }}</strong>
              <span data-test-partial-reason>{{this.partialWarning}}</span>
            </div>
          {{/if}}

          {{#if @traffic}}
            <div hidden={{@loading}}>
              {{#if @hasPageviews}}
                <section
                  class="site-traffic-explorer__metrics"
                  aria-label={{i18n "admin.site_traffic_explorer.summary"}}
                >
                  {{#each this.metrics as |metric|}}
                    <SiteTrafficMetric
                      @name={{metric.name}}
                      @label={{metric.label}}
                      @tooltip={{metric.tooltip}}
                      @value={{metric.value}}
                    />
                  {{/each}}
                </section>

                <section
                  class="site-traffic-explorer__chart"
                  aria-label={{i18n
                    "admin.site_traffic_explorer.traffic_over_time"
                  }}
                >
                  <h2>{{i18n
                      "admin.site_traffic_explorer.traffic_over_time"
                    }}</h2>
                  <AdminReportStackedChart
                    @model={{this.chartModel}}
                    @options={{this.chartOptions}}
                  />
                  <div class="sr-only">
                    {{#each this.series as |series|}}
                      <span
                        data-test-traffic-series={{series.key}}
                      >{{series.total}}</span>
                    {{/each}}
                  </div>
                </section>

                <div class="site-traffic-explorer__cards">
                  <SiteTrafficBreakdownCard
                    @name="acquisition"
                    @title={{i18n
                      "admin.site_traffic_explorer.cards.acquisition"
                    }}
                    @tabs={{this.acquisitionTabs}}
                    @dimensions={{@traffic.dimensions}}
                    @setFilter={{@setFilter}}
                  />
                  <SiteTrafficBreakdownCard
                    @name="pages"
                    @title={{i18n "admin.site_traffic_explorer.cards.pages"}}
                    @tabs={{this.pagesTabs}}
                    @dimensions={{@traffic.dimensions}}
                    @setFilter={{@setFilter}}
                  />
                  <SiteTrafficBreakdownCard
                    @name="visitors"
                    @title={{i18n "admin.site_traffic_explorer.cards.visitors"}}
                    @tabs={{this.visitorsTabs}}
                    @dimensions={{@traffic.dimensions}}
                    @setFilter={{@setFilter}}
                  />
                </div>
              {{else}}
                <div
                  class="site-traffic-explorer__empty"
                  role="status"
                  aria-live="polite"
                  data-test-site-traffic-empty
                >
                  {{i18n "admin.site_traffic_explorer.empty"}}
                </div>
              {{/if}}
            </div>
          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
