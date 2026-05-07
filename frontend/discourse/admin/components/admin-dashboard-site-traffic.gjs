import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import SiteTrafficPeriodSelector, {
  SITE_TRAFFIC_PERIODS,
} from "discourse/admin/components/site-traffic-period-selector";
import Report from "discourse/admin/models/report";
import DButton from "discourse/components/d-button";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { number } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { DeferredTrackedSet } from "discourse/lib/tracked-tools";
import { fillMissingDates } from "discourse/lib/utilities";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const REPORT_TYPE = "site_traffic_summary";

const SERIES = {
  LOGGED_IN: "page_view_logged_in_browser",
  ANON: "page_view_anon_browser",
  CRAWLER: "page_view_crawler",
};

const SERIES_COLORS = {
  [SERIES.LOGGED_IN]: "#4B3CE0",
  [SERIES.ANON]: "#9C8DEC",
  [SERIES.CRAWLER]: "#D5CDF7",
};

function ymd(date) {
  return moment(date).utc().format("YYYY-MM-DD");
}

const PRESET_DAYS_BACK = {
  [SITE_TRAFFIC_PERIODS.LAST_7_DAYS]: 6,
  [SITE_TRAFFIC_PERIODS.LAST_30_DAYS]: 29,
  [SITE_TRAFFIC_PERIODS.LAST_90_DAYS]: 89,
  [SITE_TRAFFIC_PERIODS.LAST_12_MONTHS]: 364,
};

function periodToDateRange(period, customStart, customEnd) {
  const today = moment.utc().startOf("day");
  if (period === SITE_TRAFFIC_PERIODS.CUSTOM) {
    return {
      startDate: moment.utc(customStart).startOf("day"),
      endDate: moment.utc(customEnd).startOf("day"),
    };
  }
  const daysBack =
    PRESET_DAYS_BACK[period] ??
    PRESET_DAYS_BACK[SITE_TRAFFIC_PERIODS.LAST_30_DAYS];
  return {
    startDate: today.clone().subtract(daysBack, "days"),
    endDate: today,
  };
}

function bucketingForLength(days) {
  if (days <= 31) {
    return "daily";
  } else if (days < 365) {
    return "weekly";
  }
  return "monthly";
}

function makeXTicksCallback({ bucketing, startMs, endMs }) {
  const spansYears = moment.utc(startMs).year() !== moment.utc(endMs).year();

  return function (value) {
    if (bucketing === "monthly") {
      return moment.utc(value).format("MMM YYYY");
    }

    // Weekly tick labels always show the bucket's Monday-start date,
    // regardless of where Chart.js's time axis places the tick mark
    // (Sunday end vs Monday start, depending on locale).
    const m =
      bucketing === "weekly" ? weeklyBucketStart(value) : moment.utc(value);

    if (spansYears) {
      return m.format("D MMM YYYY");
    }
    return m.format("D MMM");
  };
}

function weeklyBucketStart(ms) {
  // Weeks always run Monday → Sunday. moment's `isoWeek` starts on Monday
  // regardless of the user's locale.
  return moment.utc(ms).startOf("isoWeek");
}

function isTodayBucket(tickMs, bucketing) {
  const today = moment.utc().startOf("day");
  if (bucketing === "weekly") {
    const start = weeklyBucketStart(tickMs);
    const end = start.clone().add(6, "days");
    return today.isBetween(start, end, "day", "[]");
  }
  return moment.utc(tickMs).startOf("day").isSame(today, "day");
}

function cssVar(name) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(name)
    .trim();
}

function makeXTickColorCallback({ bucketing }) {
  // Always return a callback so all tick labels get a theme-aware color
  // (Chart.js's hardcoded default is a fixed gray that's unreadable in
  // dark mode). The today indicator (daily/weekly buckets) is stepped one
  // tone lighter than the default so it reads as more muted.
  return function (context) {
    const themeDefault = cssVar("--primary-medium");
    if (!context.tick) {
      return themeDefault;
    }
    if (bucketing === "monthly") {
      return themeDefault;
    }
    return isTodayBucket(context.tick.value, bucketing)
      ? cssVar("--primary-low")
      : themeDefault;
  };
}

function makeTooltipTitleCallback({ bucketing }) {
  // Title only — bucket-aware date display (Option C-style). The rest of
  // the tooltip is the default Chart.js layout (per-series rows + total).
  return function (tooltipItems) {
    const bucketStartMs = tooltipItems[0].parsed.x;
    if (bucketing === "monthly") {
      return moment.utc(bucketStartMs).format("MMM YYYY");
    }
    if (bucketing === "weekly") {
      const wkStart = weeklyBucketStart(bucketStartMs);
      const wkEnd = wkStart.clone().add(6, "days");
      if (wkStart.year() !== wkEnd.year()) {
        return `${wkStart.format("D MMM YYYY")} – ${wkEnd.format("D MMM YYYY")}`;
      }
      return `${wkStart.format("D MMM")} – ${wkEnd.format("D MMM YYYY")}`;
    }
    return moment.utc(bucketStartMs).format("ddd, D MMM YYYY");
  };
}

function pickRoundStep(maxValue, maxTicks) {
  if (!maxValue || maxValue <= 0) {
    return 1;
  }
  const targetSteps = Math.max(1, maxTicks - 1);
  const candidates = [1, 2, 5];
  for (let pow = 0; pow < 13; pow++) {
    for (const c of candidates) {
      const step = c * Math.pow(10, pow);
      if (Math.ceil(maxValue / step) <= targetSteps) {
        return step;
      }
    }
  }
  return Math.pow(10, 13);
}

export default class AdminDashboardSiteTraffic extends Component {
  @service siteSettings;
  @service loadingSlider;

  @tracked period = SITE_TRAFFIC_PERIODS.LAST_30_DAYS;
  @tracked customStart = null;
  @tracked customEnd = null;
  @tracked model = null;
  @tracked modelPeriod = null;
  @tracked isLoading = false;
  @tracked errored = false;

  hiddenSeries = new DeferredTrackedSet([SERIES.CRAWLER]);
  swatchStyle = (color, isActive) => {
    const c = color || "transparent";
    if (isActive) {
      return trustHTML(`background-color: ${c}; border-color: ${c};`);
    }
    return trustHTML(`background-color: transparent; border-color: ${c};`);
  };
  pillIsActive = (req) => !this.hiddenSeries.has(req);
  _requestSeq = 0;

  constructor() {
    super(...arguments);
    this.fetchReport();
  }

  get isPublicSite() {
    return !this.siteSettings.login_required;
  }

  get range() {
    return periodToDateRange(this.period, this.customStart, this.customEnd);
  }

  get startDate() {
    return this.range.startDate;
  }

  get endDate() {
    return this.range.endDate;
  }

  get periodDescriptor() {
    // Anchor the descriptor to the period the currently displayed model
    // corresponds to, so the headline doesn't briefly mix the new period
    // descriptor with stale count and trend during a fetch.
    const period = this.modelPeriod ?? this.period;
    return i18n(`admin.dashboard.site_traffic.period_descriptor.${period}`);
  }

  // Chart-rendering dates anchor to the *model* the chart is currently
  // showing, not to the live period selection. Without this, switching
  // (say) Last 30 days → Last 90 days would stretch the x-axis range and
  // re-bucket immediately on click, before the new bars arrive — the
  // chart would visibly "expand" first, then repopulate. Anchoring keeps
  // the axis stable until the new data lands.
  get modelStartDate() {
    return this.model?.start_date
      ? moment.utc(this.model.start_date, "YYYY-MM-DD").startOf("day")
      : this.startDate;
  }

  get modelEndDate() {
    return this.model?.end_date
      ? moment.utc(this.model.end_date, "YYYY-MM-DD").startOf("day")
      : this.endDate;
  }

  get currentTotals() {
    return this.model?.related_data?.current_totals;
  }

  get priorTotals() {
    return this.model?.related_data?.prior_totals;
  }

  humanTotal(totals) {
    if (!totals) {
      return 0;
    }
    const loggedIn = totals[SERIES.LOGGED_IN] || 0;
    const anon = totals[SERIES.ANON] || 0;
    return this.isPublicSite ? loggedIn + anon : loggedIn;
  }

  get headlineCount() {
    return this.humanTotal(this.currentTotals);
  }

  get priorHeadlineCount() {
    return this.humanTotal(this.priorTotals);
  }

  get hasTrendCoverage() {
    const firstDate = this.model?.related_data?.first_browser_pageview_date;
    const priorStart = this.model?.related_data?.prior_start_date;
    if (!firstDate || !priorStart) {
      return false;
    }
    return moment.utc(priorStart).isSameOrAfter(moment.utc(firstDate));
  }

  get trendDelta() {
    if (!this.hasTrendCoverage) {
      return null;
    }
    const current = this.headlineCount;
    const prior = this.priorHeadlineCount;
    if (prior === 0 || current === prior) {
      return null;
    }
    const rawPct = ((current - prior) / prior) * 100;
    // Show one decimal when the change is small; integer otherwise.
    if (Math.abs(rawPct) < 1) {
      const oneDecimal = Math.round(rawPct * 10) / 10;
      // Truly < 0.05% — round-to-zero behaves the same as no change.
      return oneDecimal === 0 ? null : oneDecimal;
    }
    return Math.round(rawPct);
  }

  get trendDirection() {
    if (this.trendDelta === null) {
      return null;
    }
    return this.trendDelta < 0 ? "down" : "up";
  }

  get headlineText() {
    const formattedCount = number(this.headlineCount);
    if (this.trendDelta === null) {
      return i18n("admin.dashboard.site_traffic.headline.count", {
        count: this.headlineCount,
        formattedCount,
        periodDescriptor: this.periodDescriptor,
      });
    }
    const directionLabel = i18n(
      `admin.dashboard.site_traffic.headline.direction_${this.trendDirection}`
    );
    return i18n("admin.dashboard.site_traffic.headline.count_with_trend", {
      count: this.headlineCount,
      formattedCount,
      periodDescriptor: this.periodDescriptor,
      direction: directionLabel,
      delta: Math.abs(this.trendDelta),
    });
  }

  get loggedInSharePercent() {
    if (!this.currentTotals) {
      return 0;
    }
    const loggedIn = this.currentTotals[SERIES.LOGGED_IN] || 0;
    const anon = this.currentTotals[SERIES.ANON] || 0;
    const denom = loggedIn + anon;
    if (denom === 0) {
      return 0;
    }
    return Math.round((loggedIn / denom) * 100);
  }

  get filterPills() {
    const pills = [
      {
        req: SERIES.LOGGED_IN,
        label: i18n("admin.dashboard.site_traffic.filters.logged_in"),
        color: this.seriesColor(SERIES.LOGGED_IN),
      },
    ];
    if (this.isPublicSite) {
      pills.push({
        req: SERIES.ANON,
        label: i18n("admin.dashboard.site_traffic.filters.anonymous"),
        color: this.seriesColor(SERIES.ANON),
      });
      pills.push({
        req: SERIES.CRAWLER,
        label: i18n("admin.dashboard.site_traffic.filters.crawlers"),
        color: this.seriesColor(SERIES.CRAWLER),
      });
    }
    return pills;
  }

  seriesColor(req) {
    return (
      SERIES_COLORS[req] || this.model?.data?.find((s) => s.req === req)?.color
    );
  }

  get visibleSeries() {
    if (!this.model?.data) {
      return [];
    }
    const allowed = this.isPublicSite
      ? [SERIES.LOGGED_IN, SERIES.ANON, SERIES.CRAWLER]
      : [SERIES.LOGGED_IN];
    return this.model.data.filter((s) => allowed.includes(s.req));
  }

  get chartModel() {
    if (!this.model) {
      return null;
    }
    const startFmt = ymd(this.modelStartDate);
    const endFmt = ymd(this.modelEndDate);
    const filledSeries = this.visibleSeries.map((series) => ({
      req: series.req,
      label: series.label,
      color: SERIES_COLORS[series.req] || series.color,
      data: fillMissingDates(
        JSON.parse(JSON.stringify(series.data)),
        startFmt,
        endFmt
      ),
    }));
    return {
      modes: this.model.modes,
      start_date: startFmt,
      end_date: endFmt,
      data: filledSeries,
      chartData: filledSeries,
    };
  }

  get bucketing() {
    const days = this.modelEndDate.diff(this.modelStartDate, "days") + 1;
    return bucketingForLength(days);
  }

  get spansYears() {
    return (
      moment.utc(this.modelStartDate).year() !==
      moment.utc(this.modelEndDate).year()
    );
  }

  get xMaxTicksLimit() {
    if (this.bucketing === "daily") {
      // Cross-year daily labels are ~2× wider (have year), so reduce density.
      return this.spansYears ? 8 : 12;
    }
    if (this.bucketing === "weekly") {
      return this.spansYears ? 8 : 14;
    }
    return 60;
  }

  get xAutoSkip() {
    // Always rely on Chart.js's auto-skip strategy. It picks a density that
    // fits the available width and respects xMaxTicksLimit; it also keeps
    // the first and last visible bars labeled via Chart.js's includeBounds
    // default.
    return true;
  }

  get maxStackHeight() {
    if (!this.model?.data) {
      return 0;
    }
    const startFmt = ymd(this.modelStartDate);
    const endFmt = ymd(this.modelEndDate);
    const visibleNotHidden = this.visibleSeries.filter(
      (s) => !this.hiddenSeries.has(s.req)
    );
    if (visibleNotHidden.length === 0) {
      return 0;
    }
    const bucketed = visibleNotHidden.map((series) => {
      const filled = fillMissingDates(
        JSON.parse(JSON.stringify(series.data)),
        startFmt,
        endFmt
      );
      return Report.collapse(this.model, filled, this.bucketing);
    });
    const buckets = bucketed[0]?.length || 0;
    let max = 0;
    for (let i = 0; i < buckets; i++) {
      let sum = 0;
      for (const s of bucketed) {
        sum += s[i]?.y || 0;
      }
      if (sum > max) {
        max = sum;
      }
    }
    return max;
  }

  get yStepSize() {
    return pickRoundStep(this.maxStackHeight, 6);
  }

  // Right edge of the chart's x-axis. Chart.js centers bars on their x
  // value, so the rightmost bar (e.g., today, the current week, or the
  // current month) needs the axis to extend past the bucket's start by
  // a full bucket width — otherwise the right half of that bar is
  // clipped.
  get xMaxBound() {
    const end = this.modelEndDate;
    if (this.bucketing === "daily") {
      return end.clone().add(1, "day");
    }
    if (this.bucketing === "weekly") {
      return weeklyBucketStart(end).clone().add(7, "days");
    }
    return end.clone().startOf("month").add(1, "month");
  }

  get chartOptions() {
    const bucketing = this.bucketing;
    const hidden = [];
    this.hiddenSeries.forEach((req) => hidden.push(req));
    return {
      chartGrouping: bucketing,
      hiddenLabels: hidden,
      showLegend: false,
      xAutoSkip: this.xAutoSkip,
      xMaxTicksLimit: this.xMaxTicksLimit,
      xTicksCallback: makeXTicksCallback({
        bucketing,
        startMs: this.modelStartDate.valueOf(),
        endMs: this.modelEndDate.valueOf(),
      }),
      xTickColorCallback: makeXTickColorCallback({ bucketing }),
      xMax: ymd(this.xMaxBound),
      xPinFirstLast: true,
      showEmptyTooltip: true,
      tooltipTitleCallback: makeTooltipTitleCallback({ bucketing }),
      yStepSize: this.yStepSize,
      yMaxTicksLimit: 6,
      yMaxRotation: 0,
    };
  }

  get crawlerTotal() {
    return this.currentTotals?.[SERIES.CRAWLER] || 0;
  }

  get hasChartData() {
    return this.headlineCount > 0 || this.crawlerTotal > 0;
  }

  get drilldownUrl() {
    return getURL(
      `/admin/reports/site_traffic?start_date=${ymd(this.startDate)}&end_date=${ymd(this.endDate)}`
    );
  }

  @action
  setPeriod(period) {
    this.period = period;
    this.customStart = null;
    this.customEnd = null;
    this.fetchReport();
  }

  @action
  setCustomDateRange(start, end) {
    this.period = SITE_TRAFFIC_PERIODS.CUSTOM;
    this.customStart = start;
    this.customEnd = end;
    this.fetchReport();
  }

  @action
  togglePill(req, event) {
    if (event?.altKey) {
      this.soloPill(req);
      return;
    }
    if (this.hiddenSeries.has(req)) {
      this.hiddenSeries.delete(req);
      return;
    }
    const visiblePills = this.filterPills.filter(
      (p) => !this.hiddenSeries.has(p.req)
    );
    if (visiblePills.length <= 1) {
      return;
    }
    this.hiddenSeries.add(req);
  }

  @action
  soloPill(req) {
    const allReqs = this.filterPills.map((p) => p.req);
    const currentlyActive = allReqs.filter((r) => !this.hiddenSeries.has(r));
    // If already soloed to this pill, restore all pills.
    if (currentlyActive.length === 1 && currentlyActive[0] === req) {
      for (const r of allReqs) {
        this.hiddenSeries.delete(r);
      }
      return;
    }
    // Otherwise, hide all pills except this one.
    for (const r of allReqs) {
      if (r === req) {
        this.hiddenSeries.delete(r);
      } else {
        this.hiddenSeries.add(r);
      }
    }
  }

  @action
  async fetchReport() {
    this._requestSeq += 1;
    const mySeq = this._requestSeq;
    const fetchPeriod = this.period;
    this.isLoading = true;
    this.errored = false;
    try {
      this.loadingSlider?.transitionStarted();
    } catch (e) {
      // Swallow — the slider is a polish, not a hard requirement.
      // eslint-disable-next-line no-console
      console.warn("loadingSlider.transitionStarted failed:", e);
    }

    try {
      const json = await ajax(`/admin/reports/${REPORT_TYPE}`, {
        data: {
          start_date: ymd(this.startDate),
          end_date: ymd(this.endDate),
        },
      });
      if (mySeq !== this._requestSeq) {
        return;
      }
      const model = Report.create({ type: REPORT_TYPE });
      model.setProperties(json.report);
      this.model = model;
      this.modelPeriod = fetchPeriod;
    } catch {
      if (mySeq !== this._requestSeq) {
        return;
      }
      this.errored = true;
    } finally {
      if (mySeq === this._requestSeq) {
        this.isLoading = false;
        try {
          this.loadingSlider?.transitionEnded();
        } catch (e) {
          // eslint-disable-next-line no-console
          console.warn("loadingSlider.transitionEnded failed:", e);
        }
      }
    }
  }

  <template>
    <section
      class="admin-dashboard-site-traffic
        {{if this.isLoading 'admin-dashboard-site-traffic--loading'}}"
    >
      <div class="admin-dashboard-site-traffic__section-header">
        <h2 class="admin-dashboard-site-traffic__heading">
          {{i18n "admin.dashboard.site_traffic.heading"}}
        </h2>
        <SiteTrafficPeriodSelector
          @period={{this.period}}
          @setPeriod={{this.setPeriod}}
          @setCustomDateRange={{this.setCustomDateRange}}
          @startDate={{this.startDate}}
          @endDate={{this.endDate}}
        />
      </div>

      <div class="admin-dashboard-site-traffic__card-wrapper">
        <div class="admin-dashboard-site-traffic__card">
          <div class="admin-dashboard-site-traffic__summary">
            <div
              class="admin-dashboard-site-traffic__headline
                {{if
                  (eq this.trendDirection 'down')
                  'admin-dashboard-site-traffic__headline--down'
                }}"
            >
              {{#if this.model}}
                <p class="admin-dashboard-site-traffic__headline-text">
                  {{this.headlineText}}
                </p>
              {{/if}}
            </div>

            {{#if this.isPublicSite}}
              <div class="admin-dashboard-site-traffic__kpi-row">
                <div class="admin-dashboard-site-traffic__kpi">
                  <div class="admin-dashboard-site-traffic__kpi-value">
                    {{this.loggedInSharePercent}}%
                  </div>
                  <div class="admin-dashboard-site-traffic__kpi-label">
                    <span>{{i18n
                        "admin.dashboard.site_traffic.kpi.label"
                      }}</span>
                    <DTooltip
                      @icon="circle-info"
                      @content={{i18n
                        "admin.dashboard.site_traffic.kpi.tooltip"
                      }}
                    />
                  </div>
                </div>
              </div>
            {{/if}}
          </div>

          {{#if this.isPublicSite}}
            <div
              class="admin-dashboard-site-traffic__pills"
              role="group"
              aria-label={{i18n "admin.dashboard.site_traffic.heading"}}
            >
              {{#each this.filterPills as |pill|}}
                <button
                  type="button"
                  class="admin-dashboard-site-traffic__pill
                    {{if
                      (this.pillIsActive pill.req)
                      'admin-dashboard-site-traffic__pill--active'
                    }}"
                  aria-pressed={{if
                    (this.pillIsActive pill.req)
                    "true"
                    "false"
                  }}
                  {{on "click" (fn this.togglePill pill.req)}}
                >
                  <span
                    class="admin-dashboard-site-traffic__pill-swatch"
                    style={{this.swatchStyle
                      pill.color
                      (this.pillIsActive pill.req)
                    }}
                  ></span>
                  {{pill.label}}
                </button>
              {{/each}}
            </div>
          {{/if}}

          <div class="admin-dashboard-site-traffic__chart">
            {{#if this.errored}}
              <div class="admin-dashboard-site-traffic__error">
                <p>{{i18n "admin.dashboard.site_traffic.chart.error"}}</p>
                <DButton
                  @label="admin.dashboard.site_traffic.chart.retry"
                  @action={{this.fetchReport}}
                />
              </div>
            {{else if this.chartModel}}
              {{#if this.hasChartData}}
                <AdminReportStackedChart
                  @model={{this.chartModel}}
                  @options={{this.chartOptions}}
                />
              {{else}}
                <div class="admin-dashboard-site-traffic__empty">
                  {{i18n "admin.dashboard.site_traffic.chart.empty"}}
                </div>
              {{/if}}
            {{/if}}
          </div>

          <div class="admin-dashboard-site-traffic__drilldown">
            <a href={{this.drilldownUrl}}>
              {{i18n "admin.dashboard.site_traffic.drilldown"}}
            </a>
          </div>
        </div>
      </div>
    </section>
  </template>
}
