import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DashboardSection from "discourse/admin/components/dashboard/section";
import { countryFlag, countryName } from "discourse/admin/lib/format-country";
import DTooltip from "discourse/float-kit/components/d-tooltip";
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
    return this.args.traffic?.kpis?.browser_pageviews?.value ?? 0;
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
    const loggedInShare = this.args.traffic?.kpis?.logged_in_share?.value;
    return loggedInShare !== null && loggedInShare !== undefined;
  }

  get loggedInShare() {
    return `${this.args.traffic?.kpis?.logged_in_share?.value ?? 0}%`;
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
            {{! <p>
              Placeholder: Logged-in traffic is growing steadily. Two spikes on
              Mar 8-9 drove a burst of anonymous visitors who didn't log in,
              pulling the logged-in share down slightly to 38%.
            </p> }}
          </div>

          {{#if this.showLoggedInShare}}
            <div class="db-section__metrics">
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
            </div>
          {{/if}}
        </div>

        {{! <div class="db-section__callout">
          Placeholder: Spikes on Mar 8 and Mar 9 - a Hacker News post linking to
          the plugin release docs drove a surge in anonymous pageviews.
        </div> }}

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
        {{else}}
          <div class="db-section__traffic-chart">
            <div class="db-section__traffic-chart-shell"></div>
          </div>
        {{/if}}

        {{#unless @fetchError}}
          {{#if @traffic}}
            {{#if (or @traffic.top_countries @traffic.top_referrers)}}
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
                            <span class="db-traffic__percent">
                              {{row.percent}}%
                            </span>
                            <span class="db-traffic__count">
                              ({{this.formatHeadlineCount row.count}})
                            </span>
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
                            <span class="db-traffic__percent">
                              {{row.percent}}%
                            </span>
                            <span class="db-traffic__count">
                              ({{this.formatHeadlineCount row.count}})
                            </span>
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
            </div>
          {{/if}}
        {{/unless}}
      </div>
    </DashboardSection>
  </template>
}
