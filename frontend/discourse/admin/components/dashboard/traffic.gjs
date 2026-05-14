import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import DashboardSection from "discourse/admin/components/dashboard/section";
import TrafficChart from "discourse/admin/components/dashboard/traffic-chart";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

const DATE_FORMAT = "YYYY-MM-DD";

export default class DashboardTraffic extends Component {
  get browserPageviews() {
    return this.args.traffic?.kpis?.browser_pageviews?.value ?? 0;
  }

  get headlineCount() {
    return this.formatHeadlineCount(this.browserPageviews);
  }

  get headlineText() {
    return i18n(this.#headlineDescriptor(this.args.period).key, {
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
    return moment(value, DATE_FORMAT);
  }

  #readDate(object, camelKey, snakeKey) {
    return object?.[camelKey] || object?.[snakeKey];
  }

  #inclusiveDayCount(startDate, endDate) {
    return this.#dateFrom(endDate).diff(this.#dateFrom(startDate), "days") + 1;
  }

  #headlineDescriptor(period) {
    switch (period) {
      case "last_7_days":
        return { key: "admin.dashboard.site_traffic.headline.last_7_days" };
      case "last_30_days":
        return { key: "admin.dashboard.site_traffic.headline.last_30_days" };
      case "last_3_months":
        return { key: "admin.dashboard.site_traffic.headline.last_3_months" };
      default:
        return {
          key: "admin.dashboard.site_traffic.headline.selected_period",
        };
    }
  }

  #comparisonTooltip(period, comparisonPeriod) {
    if (!comparisonPeriod) {
      return null;
    }

    const startDate = this.#readDate(
      comparisonPeriod,
      "startDate",
      "start_date"
    );
    const endDate = this.#readDate(comparisonPeriod, "endDate", "end_date");
    const tooltip = { startDate, endDate };

    switch (period) {
      case "last_7_days":
        return {
          ...tooltip,
          key: "admin.dashboard.site_traffic.comparison_tooltip.previous_7_days",
        };
      case "last_30_days":
        return {
          ...tooltip,
          key: "admin.dashboard.site_traffic.comparison_tooltip.previous_30_days",
        };
      case "last_3_months":
        return {
          ...tooltip,
          key: "admin.dashboard.site_traffic.comparison_tooltip.previous_3_months",
        };
      default: {
        const days = this.#inclusiveDayCount(startDate, endDate);

        return {
          ...tooltip,
          count: days,
          key: "admin.dashboard.site_traffic.comparison_tooltip.previous_days",
        };
      }
    }
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
    >
      <div class="db-traffic {{if @loading 'is-loading'}}">
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
                <div
                  class="db-section__metric-number"
                >{{this.loggedInShare}}</div>
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
          <TrafficChart
            @traffic={{@traffic}}
            @startDate={{@startDate}}
            @endDate={{@endDate}}
          />
        {{else}}
          <div class="db-section__traffic-chart">
            <div class="db-section__traffic-chart-shell"></div>
          </div>
        {{/if}}

        <div class="db-section__row">
          <div class="db-section__row-block">
            <div class="db-section__row-block-header">
              <a class="db-section__row-block-title">
                Placeholder: Top referrers
                <span class="db-link-arrow">{{dIcon "arrow-right"}}</span>
              </a>
            </div>

            <ul class="db-traffic__list">
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">news.ycombinator.com</span>
                <span class="db-traffic__value">
                  41%
                  <span class="db-traffic__count">(34.2k)</span>
                </span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">google.com</span>
                <span class="db-traffic__value">
                  29%
                  <span class="db-traffic__count">(24.5k)</span>
                </span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">github.com</span>
                <span class="db-traffic__value">
                  15%
                  <span class="db-traffic__count">(12.3k)</span>
                </span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">reddit.com/r/selfhosted</span>
                <span class="db-traffic__value">
                  10%
                  <span class="db-traffic__count">(8.0k)</span>
                </span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">duckduckgo.com</span>
                <span class="db-traffic__value">
                  5%
                  <span class="db-traffic__count">(4.8k)</span>
                </span>
              </li>
            </ul>
          </div>

          <div class="db-section__row-block">
            <h3 class="db-section__row-block-title">
              Placeholder: Top countries
            </h3>

            <ul class="db-traffic__list">
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">🇺🇸 United States</span>
                <span class="db-traffic__value">41%</span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">🇬🇧 United Kingdom</span>
                <span class="db-traffic__value">12%</span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">🇩🇪 Germany</span>
                <span class="db-traffic__value">8%</span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">🇨🇦 Canada</span>
                <span class="db-traffic__value">7%</span>
              </li>
              <li class="db-traffic__list-row">
                <span class="db-traffic__name">🇦🇺 Australia</span>
                <span class="db-traffic__value">4%</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </DashboardSection>
  </template>
}
