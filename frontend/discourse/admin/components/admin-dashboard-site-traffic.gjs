import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DashboardSection from "discourse/admin/components/dashboard/section";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { number } from "discourse/lib/formatter";
import DButton from "discourse/ui-kit/d-button";
import I18n, { i18n } from "discourse-i18n";

const REPORT_TYPE = "site_traffic_summary";
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

function ymd(date) {
  return moment
    .utc(moment(date).format("YYYY-MM-DD"), "YYYY-MM-DD")
    .format("YYYY-MM-DD");
}

let regionNames;

function regionDisplayName(countryCode) {
  const code = countryCode?.toUpperCase();

  if (!code) {
    return "";
  }

  if (typeof Intl === "undefined" || !Intl.DisplayNames) {
    return code;
  }

  try {
    regionNames ||= new Intl.DisplayNames(
      [document.documentElement.lang || "en"],
      { type: "region" }
    );

    return regionNames.of(code) || code;
  } catch {
    return code;
  }
}

function countryFlag(countryCode) {
  const code = countryCode?.toUpperCase();

  if (!/^[A-Z]{2}$/.test(code)) {
    return "";
  }

  return [...code]
    .map((char) => String.fromCodePoint(127397 + char.charCodeAt(0)))
    .join("");
}

function countryLabel(countryCode) {
  const flag = countryFlag(countryCode);
  const name = regionDisplayName(countryCode);

  return [flag, name].filter(Boolean).join(" ");
}

function rankedCountLabel(count) {
  return i18n("admin.dashboard.site_traffic.ranked_count", {
    count: number(count),
  });
}

export default class AdminDashboardSiteTraffic extends Component {
  @service loadingSlider;

  @tracked report = null;
  @tracked isLoading = false;
  @tracked errored = false;

  hiddenLabels = ["page_view_crawler"];
  _requestSeq = 0;

  constructor() {
    super(...arguments);
    this.fetchReport();
  }

  get topReferrers() {
    return (this.report?.related_data?.top_referrers || []).map((referrer) => ({
      label: referrer.source_name,
      countLabel: rankedCountLabel(referrer.count),
      percent: referrer.percent,
    }));
  }

  get hasTopReferrers() {
    return this.topReferrers.length > 0;
  }

  get topCountries() {
    return (this.report?.related_data?.top_countries || []).map((country) => ({
      label: countryLabel(country.country_code),
      countLabel: rankedCountLabel(country.count),
      percent: country.percent,
    }));
  }

  get hasTopCountries() {
    return this.topCountries.length > 0;
  }

  get browserPageviews() {
    return this.args.traffic?.kpis?.browser_pageviews?.value ?? 0;
  }

  get headlineText() {
    return i18n(this.#headlineKey(this.args.period), {
      count: this.browserPageviews,
      formatted_count: this.formatHeadlineCount(this.browserPageviews),
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
      legendPosition: "top",
    };
  }

  @action
  async fetchReport() {
    this._requestSeq += 1;
    const mySeq = this._requestSeq;

    this.isLoading = true;
    this.errored = false;
    this.loadingSlider?.transitionStarted();

    try {
      const json = await ajax(`/admin/reports/${REPORT_TYPE}`, {
        data: {
          start_date: ymd(this.args.startDate),
          end_date: ymd(this.args.endDate),
        },
      });

      if (mySeq !== this._requestSeq) {
        return;
      }

      this.report = json.report;
    } catch {
      if (mySeq !== this._requestSeq) {
        return;
      }

      this.errored = true;
    } finally {
      if (mySeq === this._requestSeq) {
        this.isLoading = false;
        this.loadingSlider?.transitionEnded();
      }
    }
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
      @title={{i18n "admin.dashboard.site_traffic.heading"}}
      @layout="column"
      class="admin-dashboard-site-traffic
        {{if this.isLoading 'admin-dashboard-site-traffic--loading'}}"
      {{didUpdate this.fetchReport @startDate @endDate @period}}
    >
      <div class="db-section__subheader">
        <div class="db-section__subintro">
          <h3 class="db-traffic__headline">
            {{this.headlineText}}
            {{#if this.trend}}
              <span class="db-traffic__headline-separator"> - </span>
              <span
                class="db-traffic__trend {{concat '--' this.trendDirection}}"
              >
                {{this.trendText}}
                <DTooltip
                  class="db-traffic__info"
                  @identifier="site-traffic-comparison-tooltip"
                  @icon="circle-info"
                >
                  <:content>{{this.comparisonTooltipText}}</:content>
                </DTooltip>
              </span>
            {{/if}}
          </h3>
          <p>
            Placeholder: Logged-in traffic is growing steadily. Two spikes on
            Mar 8-9 drove a burst of anonymous visitors who didn't log in,
            pulling the logged-in share down slightly to 38%.
          </p>
        </div>

        {{#if this.showLoggedInShare}}
          <div class="db-section__metrics">
            <div class="db-section__metric">
              <div class="db-section__metric-number">
                {{this.loggedInShare}}
              </div>
              <div class="db-section__metric-label">
                {{i18n
                  "admin.dashboard.site_traffic.kpi.logged_in_share.label"
                }}
                <DTooltip
                  class="db-traffic__info"
                  @identifier="site-traffic-logged-in-share-tooltip"
                  @icon="circle-info"
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

      <div class="db-section__callout">
        Placeholder: Spikes on Mar 8 and Mar 9 - a Hacker News post linking to
        the plugin release docs drove a surge in anonymous pageviews.
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
      {{else}}
        <div class="db-section__traffic-chart">
          <div class="db-section__traffic-chart-shell"></div>
        </div>
      {{/if}}

      {{#if this.errored}}
        <div class="admin-dashboard-site-traffic__error">
          <p>{{i18n "admin.dashboard.site_traffic.chart.error"}}</p>
          <DButton
            @label="admin.dashboard.site_traffic.chart.retry"
            @action={{this.fetchReport}}
          />
        </div>
      {{/if}}

      <div class="admin-dashboard-site-traffic__ranked-row">
        <section class="admin-dashboard-site-traffic__ranked-card">
          <h3 class="admin-dashboard-site-traffic__ranked-title">
            {{i18n "admin.dashboard.site_traffic.top_referrers.title"}}
          </h3>

          {{#if this.hasTopReferrers}}
            <ol class="admin-dashboard-site-traffic__ranked-list">
              {{#each this.topReferrers as |referrer|}}
                <li class="admin-dashboard-site-traffic__ranked-item">
                  <div class="admin-dashboard-site-traffic__ranked-line">
                    <span class="admin-dashboard-site-traffic__ranked-name">
                      {{referrer.label}}
                    </span>
                    <span class="admin-dashboard-site-traffic__ranked-value">
                      {{referrer.percent}}%
                      <span class="admin-dashboard-site-traffic__ranked-count">
                        {{referrer.countLabel}}
                      </span>
                    </span>
                  </div>
                </li>
              {{/each}}
            </ol>
          {{else}}
            <p class="admin-dashboard-site-traffic__ranked-empty">
              {{i18n "admin.dashboard.site_traffic.top_referrers.empty"}}
            </p>
          {{/if}}
        </section>

        <section class="admin-dashboard-site-traffic__ranked-card">
          <h3 class="admin-dashboard-site-traffic__ranked-title">
            {{i18n "admin.dashboard.site_traffic.top_countries.title"}}
          </h3>

          {{#if this.hasTopCountries}}
            <ol class="admin-dashboard-site-traffic__ranked-list">
              {{#each this.topCountries as |country|}}
                <li class="admin-dashboard-site-traffic__ranked-item">
                  <div class="admin-dashboard-site-traffic__ranked-line">
                    <span class="admin-dashboard-site-traffic__ranked-name">
                      {{country.label}}
                    </span>
                    <span class="admin-dashboard-site-traffic__ranked-value">
                      {{country.percent}}%
                      <span class="admin-dashboard-site-traffic__ranked-count">
                        {{country.countLabel}}
                      </span>
                    </span>
                  </div>
                </li>
              {{/each}}
            </ol>
          {{else}}
            <p class="admin-dashboard-site-traffic__ranked-empty">
              {{i18n "admin.dashboard.site_traffic.top_countries.empty"}}
            </p>
          {{/if}}
        </section>
      </div>

      <div class="admin-dashboard-site-traffic-links">
        <h2 class="admin-dashboard-site-traffic-links__heading">
          {{i18n "admin.dashboard.site_traffic.links_heading"}}
        </h2>
        <div>
          <a
            class="admin-dashboard-site-traffic-links__link"
            href="https://github.com/discourse/discourse/blob/tgxworld/site-traffic-redesign-spike/site-traffic-implementation-objectives.md"
            rel="noopener noreferrer"
            target="_blank"
          >
            {{i18n "admin.dashboard.site_traffic.objectives_link"}}
          </a>
        </div>
        <div>
          <a
            class="admin-dashboard-site-traffic-links__link"
            href="https://github.com/discourse/discourse/blob/tgxworld/site-traffic-redesign-spike/site-traffic-data-layer-design.md"
            rel="noopener noreferrer"
            target="_blank"
          >
            {{i18n "admin.dashboard.site_traffic.data_layer_link"}}
          </a>
        </div>
        <div>
          <a
            class="admin-dashboard-site-traffic-links__link"
            href="/site-traffic-headline-prototypes.html"
            rel="noopener noreferrer"
            target="_blank"
          >
            {{i18n "admin.dashboard.site_traffic.prototype_link"}}
          </a>
        </div>
      </div>
    </DashboardSection>
  </template>
}
