import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DashboardSection from "discourse/admin/components/dashboard/section";
import { countryFlag, countryName } from "discourse/admin/lib/format-country";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { formatMinutesSeconds } from "discourse/lib/formatter";
import { or } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

const PERIOD_COPY_KEYS = {
  last_7_days: {
    headline: "admin.dashboard.site_traffic.headline.last_7_days",
    comparisonTooltip:
      "admin.dashboard.site_traffic.comparison_tooltip.previous_7_days",
  },
  last_30_days: {
    headline: "admin.dashboard.site_traffic.headline.last_30_days",
    comparisonTooltip:
      "admin.dashboard.site_traffic.comparison_tooltip.previous_30_days",
  },
  last_3_months: {
    headline: "admin.dashboard.site_traffic.headline.last_3_months",
    comparisonTooltip:
      "admin.dashboard.site_traffic.comparison_tooltip.previous_3_months",
  },
};

export default class DashboardTraffic extends Component {
  hiddenLabels = ["page_view_crawler"];

  get browserPageviews() {
    return this.#kpiValue("browser_pageviews") ?? 0;
  }

  get headlineCount() {
    return this.formatHeadlineCount(this.browserPageviews);
  }

  get headlineText() {
    return i18n(this.#headlineKey(this.args.period), {
      count: this.browserPageviews,
      formatted_count: this.headlineCount,
    });
  }

  get trend() {
    const browserPageviewsKpi = this.args.traffic?.kpis?.browser_pageviews;
    const percentChange = browserPageviewsKpi?.percent_change;

    if (percentChange === null || percentChange === undefined) {
      return null;
    }

    return browserPageviewsKpi;
  }

  get trendDirection() {
    return this.trend?.percent_change > 0 ? "up" : "down";
  }

  get trendText() {
    if (!this.trend) {
      return null;
    }

    return i18n(`admin.dashboard.site_traffic.trend.${this.trendDirection}`, {
      percent: this.formatTrendPercent(Math.abs(this.trend.percent_change)),
    });
  }

  get comparisonTooltipText() {
    const tooltip = this.#comparisonTooltip(
      this.args.period,
      this.trend?.comparison_period
    );

    if (!tooltip) {
      return null;
    }

    return i18n(tooltip.key, {
      count: tooltip.count,
      ...this.#formatComparisonDates(tooltip.startDate, tooltip.endDate),
    });
  }

  get showLoggedInShare() {
    return this.#kpiValue("logged_in_share") != null;
  }

  get loggedInShare() {
    return `${this.#kpiValue("logged_in_share") ?? 0}%`;
  }

  get showDirectTraffic() {
    return this.#kpiValue("direct_traffic") != null;
  }

  get directTraffic() {
    return `${this.#kpiValue("direct_traffic") ?? 0}%`;
  }

  #kpiValue(key) {
    return this.args.traffic?.kpis?.[key]?.value;
  }

  get showSessionMetrics() {
    return this.#kpiValue("bounce_rate") !== undefined;
  }

  get showMetrics() {
    return (
      this.showLoggedInShare ||
      this.showDirectTraffic ||
      this.showSessionMetrics
    );
  }

  get sessionMetricsEmpty() {
    return this.#kpiValue("bounce_rate") == null;
  }

  get bounceRate() {
    const value = this.#kpiValue("bounce_rate");
    return value == null ? "—" : `${value}%`;
  }

  get averageSessionDuration() {
    const value = this.#kpiValue("average_session_duration_seconds");
    return value == null ? "—" : formatMinutesSeconds(value);
  }

  get chartModel() {
    return {
      start_date: this.args.startDate,
      end_date: this.args.endDate,
      data: this.args.traffic?.pageview_series ?? [],
    };
  }

  get chartOptions() {
    return {
      hideYAxisGridLines: true,
      hiddenLabels: this.hiddenLabels,
    };
  }

  get reportQuery() {
    return {
      start_date: moment(this.args.startDate).format("YYYY-MM-DD"),
      end_date: moment(this.args.endDate).format("YYYY-MM-DD"),
    };
  }

  formatHeadlineCount(value) {
    if (value >= 1_000_000) {
      const formatted = I18n.toNumber(value / 1_000_000, { precision: 1 });
      return `${formatted.replace(/[,.]0$/, "")}M`;
    }

    if (value >= 1_000) {
      return `${I18n.toNumber(Math.round(value / 1_000), { precision: 0 })}k`;
    }

    return I18n.toNumber(value, { precision: 0 });
  }

  formatTrendPercent(value) {
    const precision = value < 1 ? 1 : 0;
    return `${I18n.toNumber(value, { precision })}%`;
  }

  #dateFrom(value) {
    return moment(value, "YYYY-MM-DD");
  }

  #inclusiveDayCount(startDate, endDate) {
    return this.#dateFrom(endDate).diff(this.#dateFrom(startDate), "days") + 1;
  }

  #headlineKey(period) {
    return (
      PERIOD_COPY_KEYS[period]?.headline ??
      "admin.dashboard.site_traffic.headline.selected_period"
    );
  }

  #comparisonTooltip(period, comparisonPeriod) {
    if (!comparisonPeriod) {
      return null;
    }

    const startDate = comparisonPeriod.start_date;
    const endDate = comparisonPeriod.end_date;
    const tooltip = { startDate, endDate };
    const presetKey = PERIOD_COPY_KEYS[period]?.comparisonTooltip;

    if (presetKey) {
      return { ...tooltip, key: presetKey };
    }

    return {
      ...tooltip,
      count: this.#inclusiveDayCount(startDate, endDate),
      key: "admin.dashboard.site_traffic.comparison_tooltip.previous_days",
    };
  }

  #formatComparisonDates(startDate, endDate) {
    const start = this.#dateFrom(startDate);
    const end = this.#dateFrom(endDate);
    const dateWithYear = (date) =>
      date.format(i18n("dates.long_with_year_no_time"));
    const dateWithoutYear = (date) =>
      date.format(i18n("dates.long_no_year_no_time"));

    if (start.isSame(end, "day")) {
      const date = dateWithYear(start);
      return { start: date, end: date };
    }

    if (start.year() === end.year()) {
      return { start: dateWithoutYear(start), end: dateWithYear(end) };
    }

    return { start: dateWithYear(start), end: dateWithYear(end) };
  }

  <template>
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.traffic.title"}}
      @startDate={{@startDate}}
      @endDate={{@endDate}}
      ...attributes
    >
      <div class="db-traffic {{if @loading 'is-loading'}}">
        <div class="db-section__subheader">
          <div class="db-section__subintro">
            <h3>
              {{this.headlineText}}
              {{#if this.trend}}
                —
                <span class="db-traffic__trend --{{this.trendDirection}}">
                  {{this.trendText}}
                </span>
                <DTooltip
                  class="db-section__info"
                  @identifier="site-traffic-comparison-tooltip"
                  @icon="far-circle-question"
                >
                  <:content>{{this.comparisonTooltipText}}</:content>
                </DTooltip>
              {{/if}}
            </h3>
          </div>

          {{#if this.showMetrics}}
            <div class="db-section__metrics">
              {{#if this.showLoggedInShare}}
                <div class="db-section__metric">
                  <div
                    class="db-section__metric-number"
                  >{{this.loggedInShare}}</div>
                  <div class="db-section__metric-label">
                    {{i18n
                      "admin.dashboard.site_traffic.kpi.logged_in_share.label"
                    }}
                    <DTooltip
                      class="db-section__info"
                      @identifier="site-traffic-logged-in-share-tooltip"
                      @icon="far-circle-question"
                    >
                      <:content>
                        {{i18n
                          "admin.dashboard.site_traffic.kpi.logged_in_share.tooltip"
                        }}
                      </:content>
                    </DTooltip>
                  </div>
                </div>
              {{/if}}

              {{#if this.showDirectTraffic}}
                <div class="db-section__metric">
                  <div
                    class="db-section__metric-number"
                  >{{this.directTraffic}}</div>
                  <div class="db-section__metric-label">
                    {{i18n
                      "admin.dashboard.site_traffic.kpi.direct_traffic.label"
                    }}
                    <DTooltip
                      class="db-section__info"
                      @identifier="site-traffic-direct-traffic-tooltip"
                      @icon="far-circle-question"
                    >
                      <:content>
                        {{i18n
                          "admin.dashboard.site_traffic.kpi.direct_traffic.tooltip"
                        }}
                      </:content>
                    </DTooltip>
                  </div>
                </div>
              {{/if}}

              {{#if this.showSessionMetrics}}
                <div class="db-section__metric" data-test-kpi="bounce_rate">
                  <div
                    class="db-section__metric-number"
                  >{{this.bounceRate}}</div>
                  <div class="db-section__metric-label">
                    {{i18n
                      "admin.dashboard.site_traffic.kpi.bounce_rate.label"
                    }}
                    <DTooltip
                      class="db-section__info"
                      @identifier="site-traffic-bounce-rate-tooltip"
                      @icon="far-circle-question"
                    >
                      <:content>
                        {{#if this.sessionMetricsEmpty}}
                          {{i18n
                            "admin.dashboard.site_traffic.kpi.session_metrics.empty_tooltip"
                          }}
                        {{else}}
                          {{i18n
                            "admin.dashboard.site_traffic.kpi.bounce_rate.tooltip"
                          }}
                        {{/if}}
                      </:content>
                    </DTooltip>
                  </div>
                </div>

                <div
                  class="db-section__metric"
                  data-test-kpi="average_session_duration"
                >
                  <div
                    class="db-section__metric-number"
                  >{{this.averageSessionDuration}}</div>
                  <div class="db-section__metric-label">
                    {{i18n
                      "admin.dashboard.site_traffic.kpi.average_session_duration.label"
                    }}
                    <DTooltip
                      class="db-section__info"
                      @identifier="site-traffic-average-session-duration-tooltip"
                      @icon="far-circle-question"
                    >
                      <:content>
                        {{#if this.sessionMetricsEmpty}}
                          {{i18n
                            "admin.dashboard.site_traffic.kpi.session_metrics.empty_tooltip"
                          }}
                        {{else}}
                          {{i18n
                            "admin.dashboard.site_traffic.kpi.average_session_duration.tooltip"
                          }}
                        {{/if}}
                      </:content>
                    </DTooltip>
                  </div>
                </div>
              {{/if}}
            </div>
          {{/if}}
        </div>

        {{#if @fetchError}}
          <div class="db-section__traffic-chart">
            <div class="db-section__traffic-chart-message" role="alert">
              {{i18n "admin.dashboard.site_traffic.fetch_error"}}
            </div>
          </div>
        {{else if @traffic}}
          <div class="db-section__traffic-chart">
            <AdminReportStackedChart
              @model={{this.chartModel}}
              @options={{this.chartOptions}}
              class="db-section__traffic-chart-canvas"
            />
          </div>
          <div class="db-traffic__actions">
            <LinkTo
              class="db-traffic__see-details"
              @route="adminReports.show"
              @model="site_traffic"
              @query={{hash
                start_date=this.reportQuery.start_date
                end_date=this.reportQuery.end_date
              }}
            >
              {{i18n "admin.dashboard.site_traffic.see_details"}}
              {{dIcon "arrow-right"}}
            </LinkTo>
          </div>
        {{else}}
          <div class="db-section__traffic-chart">
            <div class="db-section__traffic-chart-shell"></div>
          </div>
        {{/if}}

        {{#unless @fetchError}}
          {{#if @traffic}}
            {{#if
              (or
                @traffic.top_countries @traffic.top_referrers @traffic.top_urls
              )
            }}
              <div class="db-section__row">
                <div class="db-section__row-block">
                  <h3 class="db-section__row-block-title">
                    <LinkTo
                      @route="adminReports.show"
                      @model="top_referrers_by_browser_pageviews"
                      @query={{hash
                        start_date=this.reportQuery.start_date
                        end_date=this.reportQuery.end_date
                      }}
                    >
                      {{i18n
                        "admin.dashboard.site_traffic.top_referrers.title"
                      }}
                      <span class="db-link-arrow" aria-hidden="true">
                        {{dIcon "arrow-right"}}
                      </span>
                    </LinkTo>
                  </h3>
                  {{#if @traffic.top_referrers.error}}
                    <p class="db-traffic__list-error" role="status">
                      {{i18n
                        "admin.dashboard.site_traffic.top_referrers.error"
                      }}
                    </p>
                  {{else if @traffic.top_referrers.rows.length}}
                    <ul class="db-traffic__list">
                      {{#each @traffic.top_referrers.rows as |row|}}
                        <li class="db-traffic__list-row">
                          <a
                            class="db-traffic__link"
                            href={{concat "https://" row.normalized_referrer}}
                            rel="noopener noreferrer nofollow ugc"
                            target="_blank"
                          >
                            {{row.normalized_referrer}}
                          </a>
                          <span class="db-traffic__metric">
                            {{this.formatHeadlineCount row.count}}
                          </span>
                        </li>
                      {{/each}}
                    </ul>
                  {{else}}
                    <p class="db-traffic__list-empty">
                      {{i18n
                        "admin.dashboard.site_traffic.top_referrers.empty"
                      }}
                    </p>
                  {{/if}}
                </div>

                <div class="db-section__row-block">
                  <h3 class="db-section__row-block-title">
                    <LinkTo
                      @route="adminReports.show"
                      @model="top_countries_by_browser_pageviews"
                      @query={{hash
                        start_date=this.reportQuery.start_date
                        end_date=this.reportQuery.end_date
                      }}
                    >
                      {{i18n
                        "admin.dashboard.site_traffic.top_countries.title"
                      }}
                      <span class="db-link-arrow" aria-hidden="true">
                        {{dIcon "arrow-right"}}
                      </span>
                    </LinkTo>
                  </h3>
                  {{#if @traffic.top_countries.error}}
                    <p class="db-traffic__list-error" role="status">
                      {{i18n
                        "admin.dashboard.site_traffic.top_countries.error"
                      }}
                    </p>
                  {{else if @traffic.top_countries.rows.length}}
                    <ul class="db-traffic__list">
                      {{#each @traffic.top_countries.rows as |row|}}
                        <li
                          class="db-traffic__list-row"
                          data-test-country-code={{row.country_code}}
                        >
                          <span class="db-traffic__name">
                            <span aria-hidden="true">
                              {{countryFlag row.country_code}}
                            </span>
                            {{countryName row.country_code}}
                          </span>
                          <span class="db-traffic__metric">
                            {{this.formatHeadlineCount row.count}}
                          </span>
                        </li>
                      {{/each}}
                    </ul>
                  {{else}}
                    <p class="db-traffic__list-empty">
                      {{i18n
                        "admin.dashboard.site_traffic.top_countries.empty"
                      }}
                    </p>
                  {{/if}}
                </div>

                {{#if @traffic.top_urls}}
                  <div class="db-section__row-block">
                    <h3 class="db-section__row-block-title">
                      <LinkTo
                        @route="adminReports.show"
                        @model="top_urls_by_browser_pageviews"
                        @query={{hash
                          start_date=this.reportQuery.start_date
                          end_date=this.reportQuery.end_date
                        }}
                      >
                        {{i18n "admin.dashboard.site_traffic.top_urls.title"}}
                        <span class="db-link-arrow" aria-hidden="true">
                          {{dIcon "arrow-right"}}
                        </span>
                      </LinkTo>
                    </h3>
                    {{#if @traffic.top_urls.error}}
                      <p class="db-traffic__list-error" role="status">
                        {{i18n "admin.dashboard.site_traffic.top_urls.error"}}
                      </p>
                    {{else if @traffic.top_urls.rows.length}}
                      <ul class="db-traffic__list">
                        {{#each @traffic.top_urls.rows as |row|}}
                          <li class="db-traffic__list-row">
                            <span class="db-traffic__name">
                              {{row.normalized_url}}
                            </span>
                            <span class="db-traffic__metric">
                              {{this.formatHeadlineCount row.count}}
                            </span>
                          </li>
                        {{/each}}
                      </ul>
                    {{else}}
                      <p class="db-traffic__list-empty">
                        {{i18n "admin.dashboard.site_traffic.top_urls.empty"}}
                      </p>
                    {{/if}}
                  </div>
                {{/if}}
              </div>
            {{/if}}
          {{else}}
            <div class="db-section__row">
              <div class="db-section__row-block">
                <h3 class="db-section__row-block-title">
                  {{i18n "admin.dashboard.site_traffic.top_referrers.title"}}
                </h3>
                <div class="db-traffic__list-shell"></div>
              </div>
              <div class="db-section__row-block">
                <h3 class="db-section__row-block-title">
                  {{i18n "admin.dashboard.site_traffic.top_countries.title"}}
                </h3>
                <div class="db-traffic__list-shell"></div>
              </div>
              <div class="db-section__row-block">
                <h3 class="db-section__row-block-title">
                  {{i18n "admin.dashboard.site_traffic.top_urls.title"}}
                </h3>
                <div class="db-traffic__list-shell"></div>
              </div>
            </div>
          {{/if}}
        {{/unless}}
      </div>
    </DashboardSection>
  </template>
}
