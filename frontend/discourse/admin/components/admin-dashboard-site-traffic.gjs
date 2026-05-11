import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DashboardSection from "discourse/admin/components/dashboard/section";
import SiteTrafficPeriodSelector, {
  SITE_TRAFFIC_PERIODS,
} from "discourse/admin/components/site-traffic-period-selector";
import Report from "discourse/admin/models/report";
import DButton from "discourse/components/d-button";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { number } from "discourse/lib/formatter";
import loadChartJS from "discourse/lib/load-chart-js";
import { DeferredTrackedSet } from "discourse/lib/tracked-tools";
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

const PRESET_DAYS_BACK = {
  [SITE_TRAFFIC_PERIODS.LAST_7_DAYS]: 6,
  [SITE_TRAFFIC_PERIODS.LAST_30_DAYS]: 29,
  [SITE_TRAFFIC_PERIODS.LAST_90_DAYS]: 89,
  [SITE_TRAFFIC_PERIODS.LAST_12_MONTHS]: 364,
};

function ymd(date) {
  return moment.utc(date).format("YYYY-MM-DD");
}

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
  }
  if (days < 365) {
    return "weekly";
  }
  return "monthly";
}

// Aggregate a per-day series into bucket totals. Each bucket's `start` is the
// first day of *actual data* in that bucket (period start for the leftmost
// partial bucket, bucket Monday/first-of-month otherwise) and `end` is the
// last day of actual data. The bar's x-axis label and tooltip both anchor to
// `start` so what you see is what the bar represents.
function bucketize(seriesData, bucketing) {
  if (bucketing === "daily") {
    return seriesData.map((d) => ({ start: d.x, end: d.x, total: d.y }));
  }
  const buckets = new Map();
  for (const d of seriesData) {
    let groupKey;
    if (bucketing === "weekly") {
      groupKey = moment
        .utc(d.x, "YYYY-MM-DD")
        .startOf("isoWeek")
        .format("YYYY-MM-DD");
    } else {
      groupKey = `${d.x.substring(0, 7)}-01`;
    }
    const existing = buckets.get(groupKey);
    if (existing) {
      existing.total += d.y;
      existing.end = d.x;
    } else {
      buckets.set(groupKey, { start: d.x, end: d.x, total: d.y });
    }
  }
  return Array.from(buckets.values());
}

function abbreviationHasDecimal(value) {
  const abs = Math.abs(value);
  if (abs < 1e3) {
    return false;
  }
  if (abs < 1e6) {
    return abs % 1e3 !== 0;
  }
  if (abs < 1e9) {
    return abs % 1e6 !== 0;
  }
  return abs % 1e9 !== 0;
}

// Pick a y-axis step that fits maxTicks ticks AND never produces decimal
// abbreviations on tick labels (no "1.5M", no "250k") — §7.7.
function pickRoundStep(maxValue, maxTicks) {
  if (!maxValue || maxValue <= 0) {
    return 1;
  }
  const targetSteps = Math.max(1, maxTicks - 1);
  const candidates = [1, 2, 5];
  for (let pow = 0; pow < 13; pow++) {
    for (const c of candidates) {
      const step = c * Math.pow(10, pow);
      if (Math.ceil(maxValue / step) > targetSteps) {
        continue;
      }
      let bad = false;
      const numTicks = Math.ceil(maxValue / step) + 1;
      for (let i = 0; i < numTicks && !bad; i++) {
        if (abbreviationHasDecimal(i * step)) {
          bad = true;
        }
      }
      if (!bad) {
        return step;
      }
    }
  }
  return Math.pow(10, 13);
}

// Format a number for the y-axis: "0", "20k", "1M", "3M". Never "20.0k" or
// "1.5M" — `pickRoundStep` only chooses steps whose ticks land on whole-power
// abbreviation boundaries, so this rounder is safe.
function formatRoundAbbr(value) {
  if (!value) {
    return "0";
  }
  const sign = value < 0 ? "-" : "";
  const abs = Math.abs(value);
  if (abs >= 1e9) {
    return `${sign}${Math.round(abs / 1e9)}G`;
  }
  if (abs >= 1e6) {
    return `${sign}${Math.round(abs / 1e6)}M`;
  }
  if (abs >= 1e3) {
    return `${sign}${Math.round(abs / 1e3)}k`;
  }
  return `${sign}${abs}`;
}

// Pick the indexes that render an x-axis label given a total count and a max
// density. Uses a fixed integer stride so the gaps between labels are uniform
// (no jitter from cumulative rounding); always pins the first and last
// indexes per §7.5. The last gap can be shorter than `stride` since the last
// index is pinned independently.
function computeVisibleIndexes(total, maxLabels) {
  if (total <= 0) {
    return new Set();
  }
  if (total <= maxLabels) {
    return new Set(Array.from({ length: total }, (_, i) => i));
  }
  const stride = Math.ceil((total - 1) / (maxLabels - 1));
  const result = new Set();
  for (let i = 0; i < total; i += stride) {
    result.add(i);
  }
  result.add(total - 1);
  return result;
}

function formatBucketLabel(key, bucketing, spansYears) {
  const m = moment.utc(key, "YYYY-MM-DD");
  if (bucketing === "monthly") {
    return m.format("MMM YYYY");
  }
  if (spansYears) {
    return m.format("D MMM YYYY");
  }
  return m.format("D MMM");
}

function formatTooltipTitle(bucket, bucketing) {
  // Both the x-axis label and the tooltip use `bucket.start`, so they always
  // describe the same bucket boundary. `bucket.end` is the actual last day
  // of data in the bucket — already clamped to the period inside `bucketize`,
  // so partial first/last weeks just work.
  const start = moment.utc(bucket.start, "YYYY-MM-DD");
  if (bucketing === "monthly") {
    return start.format("MMM YYYY");
  }
  if (bucketing === "weekly") {
    const end = moment.utc(bucket.end, "YYYY-MM-DD");
    if (start.isSame(end, "day")) {
      return start.format("D MMM YYYY");
    }
    if (start.year() !== end.year()) {
      return `${start.format("D MMM YYYY")} – ${end.format("D MMM YYYY")}`;
    }
    return `${start.format("D MMM")} – ${end.format("D MMM YYYY")}`;
  }
  return start.format("ddd, D MMM YYYY");
}

function cssVar(name) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(name)
    .trim();
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
      {
        type: "region",
      }
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

// Reactive Chart.js wrapper: builds the chart on first render and rebuilds
// from scratch whenever `chartConfig` changes (period swap, filter pill
// toggle). Chart.js init is fast enough that a full rebuild is fine.
const renderChart = modifier(function (element, [chartConfig]) {
  if (!chartConfig) {
    return;
  }
  let chart;
  let cancelled = false;
  loadChartJS().then((Chart) => {
    if (cancelled) {
      return;
    }
    chart = new Chart(element.getContext("2d"), chartConfig);
  });
  return () => {
    cancelled = true;
    chart?.destroy();
  };
});

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
  pillIsActive = (req) => !this.hiddenSeries.has(req);
  swatchStyle = (color, isActive) => {
    const c = color || "transparent";
    return isActive
      ? trustHTML(`background-color: ${c}; border-color: ${c};`)
      : trustHTML(`background-color: transparent; border-color: ${c};`);
  };
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
    // Anchor the descriptor to the period the *displayed model* came from so
    // the headline doesn't briefly mix a new period descriptor with stale
    // counts during a fetch (§3.6).
    const period = this.modelPeriod ?? this.period;
    return i18n(`admin.dashboard.site_traffic.period_descriptor.${period}`);
  }

  get modelStartDate() {
    return this.model?.start_date
      ? moment.utc(this.model.start_date, "YYYY-MM-DD").startOf("day")
      : null;
  }

  get modelEndDate() {
    return this.model?.end_date
      ? moment.utc(this.model.end_date, "YYYY-MM-DD").startOf("day")
      : null;
  }

  get bucketing() {
    if (!this.modelStartDate || !this.modelEndDate) {
      return "daily";
    }
    const days = this.modelEndDate.diff(this.modelStartDate, "days") + 1;
    return bucketingForLength(days);
  }

  get spansYears() {
    if (!this.modelStartDate || !this.modelEndDate) {
      return false;
    }
    return this.modelStartDate.year() !== this.modelEndDate.year();
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
    if (Math.abs(rawPct) < 0.05) {
      return null;
    }
    if (Math.abs(rawPct) < 1) {
      return (Math.sign(rawPct) * Math.round(Math.abs(rawPct) * 10)) / 10;
    }
    return Math.round(rawPct);
  }

  get trendDirection() {
    if (this.trendDelta === null) {
      return null;
    }
    return this.trendDelta < 0 ? "down" : "up";
  }

  get headlineCountText() {
    const formattedCount = number(this.headlineCount);
    return i18n("admin.dashboard.site_traffic.headline.count", {
      count: this.headlineCount,
      formattedCount,
      periodDescriptor: this.periodDescriptor,
    });
  }

  get trendPhraseText() {
    if (this.trendDelta === null) {
      return null;
    }
    const directionLabel = i18n(
      `admin.dashboard.site_traffic.headline.direction_${this.trendDirection}`
    );
    return i18n("admin.dashboard.site_traffic.headline.trend_phrase", {
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
        color: SERIES_COLORS[SERIES.LOGGED_IN],
      },
    ];
    if (this.isPublicSite) {
      pills.push({
        req: SERIES.ANON,
        label: i18n("admin.dashboard.site_traffic.filters.anonymous"),
        color: SERIES_COLORS[SERIES.ANON],
      });
      pills.push({
        req: SERIES.CRAWLER,
        label: i18n("admin.dashboard.site_traffic.filters.crawlers"),
        color: SERIES_COLORS[SERIES.CRAWLER],
      });
    }
    return pills;
  }

  // Aggregated bucket totals per series, keyed by req. All series share the
  // same bucket keys (same date range, same bucketing).
  get bucketsBySeries() {
    if (!this.model?.data) {
      return new Map();
    }
    const allowed = this.isPublicSite
      ? [SERIES.LOGGED_IN, SERIES.ANON, SERIES.CRAWLER]
      : [SERIES.LOGGED_IN];
    const result = new Map();
    for (const series of this.model.data) {
      if (!allowed.includes(series.req)) {
        continue;
      }
      result.set(series.req, bucketize(series.data, this.bucketing));
    }
    return result;
  }

  // The shared bucket spine (same shape across all series): one entry per
  // bucket, with `start`/`end`/`total`. Any series's bucket array works since
  // they all aggregate the same period with the same bucketing.
  get buckets() {
    const first = this.bucketsBySeries.values().next().value;
    return first ?? [];
  }

  // Date strings used as the chart's category labels and as a stable lookup
  // key for tooltip → bucket mapping.
  get bucketStarts() {
    return this.buckets.map((b) => b.start);
  }

  get visibleSeriesReqs() {
    return Array.from(this.bucketsBySeries.keys()).filter(
      (req) => !this.hiddenSeries.has(req)
    );
  }

  get hasChartData() {
    if (this.bucketsBySeries.size === 0) {
      return false;
    }
    for (const buckets of this.bucketsBySeries.values()) {
      for (const bucket of buckets) {
        if (bucket.total > 0) {
          return true;
        }
      }
    }
    return false;
  }

  get showEmptyState() {
    return Boolean(this.model) && !this.hasChartData;
  }

  // Max stack height across all visible (non-hidden) buckets. Used to pick
  // a clean y-axis step.
  get visibleStackHeight() {
    const visibleReqs = this.visibleSeriesReqs;
    if (visibleReqs.length === 0) {
      return 0;
    }
    const total = this.buckets.length;
    let max = 0;
    for (let i = 0; i < total; i++) {
      let sum = 0;
      for (const req of visibleReqs) {
        sum += this.bucketsBySeries.get(req)[i]?.total || 0;
      }
      if (sum > max) {
        max = sum;
      }
    }
    return max;
  }

  get xMaxLabels() {
    // Cross-year daily/weekly labels are wider (have year), so reduce density.
    if (this.bucketing === "daily") {
      return this.spansYears ? 8 : 12;
    }
    if (this.bucketing === "weekly") {
      return this.spansYears ? 8 : 14;
    }
    return 60; // monthly: ≤13 buckets, label them all.
  }

  get xVisibleIndexes() {
    return computeVisibleIndexes(this.buckets.length, this.xMaxLabels);
  }

  get crawlerTotal() {
    return this.currentTotals?.[SERIES.CRAWLER] || 0;
  }

  get topReferrers() {
    return (this.model?.related_data?.top_referrers || []).map((referrer) => ({
      label: referrer.source_name,
      count: number(referrer.count),
      percent: referrer.percent,
    }));
  }

  get hasTopReferrers() {
    return this.topReferrers.length > 0;
  }

  get topCountries() {
    return (this.model?.related_data?.top_countries || []).map((country) => ({
      label: countryLabel(country.country_code),
      count: number(country.count),
      percent: country.percent,
    }));
  }

  get hasTopCountries() {
    return this.topCountries.length > 0;
  }

  // Build the Chart.js config from scratch in one place. Category x-axis
  // means bars at integer indexes 0..N-1, equal-width slots, labels rendered
  // exactly under their bars. No timezone math anywhere — `keys` are opaque
  // strings, only formatted (with `moment.utc`) at label render time.
  get chartConfig() {
    if (this.bucketsBySeries.size === 0) {
      return null;
    }
    const buckets = this.buckets;
    const labels = this.bucketStarts;
    const bucketing = this.bucketing;
    const spansYears = this.spansYears;
    const visibleIndexes = this.xVisibleIndexes;

    const themeDefault = cssVar("--primary-medium");
    const gridColor = cssVar("--primary-very-low");
    const tooltipBg = cssVar("--primary");
    const tooltipFg = cssVar("--secondary");

    // Render order matters: stack from logged-in (bottom) → anon → crawlers
    // (top), §7.3.
    const seriesOrder = [SERIES.LOGGED_IN, SERIES.ANON, SERIES.CRAWLER].filter(
      (req) => this.bucketsBySeries.has(req)
    );

    const datasets = seriesOrder.map((req) => ({
      label: this.seriesLabel(req),
      data: this.bucketsBySeries.get(req).map((b) => b.total),
      backgroundColor: SERIES_COLORS[req],
      stack: "pageviews-stack",
      hidden: this.hiddenSeries.has(req),
      borderRadius: 2,
      maxBarThickness: 30,
      // §7.6b — every bucket renders a visible bar even when its value is 0.
      minBarLength: 3,
      // Stash req so the tooltip footer can split humans vs crawlers.
      req,
    }));

    const pageviewsLabel = i18n(
      "admin.dashboard.site_traffic.chart.tooltip.pageviews"
    );
    const crawlersLabel = i18n(
      "admin.dashboard.site_traffic.chart.tooltip.crawlers"
    );

    return {
      type: "bar",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 300 },
        hover: { mode: "index" },
        plugins: {
          legend: { display: false },
          tooltip: {
            mode: "index",
            intersect: false,
            backgroundColor: tooltipBg,
            titleColor: tooltipFg,
            bodyColor: tooltipFg,
            footerColor: tooltipFg,
            titleMarginBottom: 16,
            footerMarginTop: 16,
            padding: { left: 20, right: 20, top: 12, bottom: 12 },
            bodySpacing: 8,
            cornerRadius: 8,
            boxPadding: 4,
            callbacks: {
              title: (items) =>
                formatTooltipTitle(buckets[items[0].dataIndex], bucketing),
              beforeFooter: (items) => {
                let humans = 0;
                let crawlers = 0;
                let crawlersVisible = false;
                for (const item of items) {
                  const v = parseInt(item.parsed.y || 0, 10);
                  const r = item.dataset.req;
                  if (r === SERIES.CRAWLER) {
                    crawlers += v;
                    crawlersVisible = true;
                  } else if (r === SERIES.LOGGED_IN || r === SERIES.ANON) {
                    humans += v;
                  }
                }
                const lines = [`${pageviewsLabel}: ${humans.toLocaleString()}`];
                if (crawlersVisible) {
                  lines.push(`${crawlersLabel}: ${crawlers.toLocaleString()}`);
                }
                return lines;
              },
            },
          },
        },
        scales: {
          x: {
            type: "category",
            stacked: true,
            offset: true,
            grid: { display: false },
            ticks: {
              autoSkip: false,
              maxRotation: 0,
              minRotation: 0,
              color: themeDefault,
              font: { size: 11 },
              callback(value, index) {
                if (!visibleIndexes.has(index)) {
                  return "";
                }
                return formatBucketLabel(labels[index], bucketing, spansYears);
              },
            },
          },
          y: {
            type: "linear",
            beginAtZero: true,
            stacked: true,
            grid: { color: gridColor },
            ticks: {
              font: { size: 11 },
              color: themeDefault,
              callback: formatRoundAbbr,
              stepSize: pickRoundStep(this.visibleStackHeight, 6),
              maxTicksLimit: 6,
              maxRotation: 0,
            },
          },
        },
      },
    };
  }

  seriesLabel(req) {
    if (req === SERIES.LOGGED_IN) {
      return i18n("admin.dashboard.site_traffic.filters.logged_in");
    }
    if (req === SERIES.ANON) {
      return i18n("admin.dashboard.site_traffic.filters.anonymous");
    }
    return i18n("admin.dashboard.site_traffic.filters.crawlers");
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
    if (currentlyActive.length === 1 && currentlyActive[0] === req) {
      for (const r of allReqs) {
        this.hiddenSeries.delete(r);
      }
      return;
    }
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

      if (
        this.isPublicSite &&
        this.humanTotal(this.currentTotals) === 0 &&
        this.crawlerTotal > 0
      ) {
        this.hiddenSeries.delete(SERIES.CRAWLER);
      }
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
    <DashboardSection
      @title={{i18n "admin.dashboard.site_traffic.heading"}}
      @layout="column"
      class="admin-dashboard-site-traffic
        {{if this.isLoading 'admin-dashboard-site-traffic--loading'}}"
    >
      <div class="admin-dashboard-site-traffic__period-row">
        <SiteTrafficPeriodSelector
          @period={{this.period}}
          @setPeriod={{this.setPeriod}}
          @setCustomDateRange={{this.setCustomDateRange}}
          @startDate={{this.startDate}}
          @endDate={{this.endDate}}
        />
      </div>

      <div class="admin-dashboard-site-traffic__summary">
        <div class="admin-dashboard-site-traffic__headline">
          {{#if this.model}}
            <p class="admin-dashboard-site-traffic__headline-text">
              {{this.headlineCountText}}
              {{#if this.trendPhraseText}}
                —
                <span
                  class="admin-dashboard-site-traffic__trend admin-dashboard-site-traffic__trend--{{this.trendDirection}}"
                >{{this.trendPhraseText}}</span>
              {{/if}}
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
                <span>{{i18n "admin.dashboard.site_traffic.kpi.label"}}</span>
                <DTooltip
                  @icon="circle-info"
                  @content={{i18n "admin.dashboard.site_traffic.kpi.tooltip"}}
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
              aria-pressed={{if (this.pillIsActive pill.req) "true" "false"}}
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
        {{else if this.chartConfig}}
          <div class="admin-dashboard-site-traffic__chart-canvas">
            <canvas {{renderChart this.chartConfig}}></canvas>
          </div>
          {{#if this.showEmptyState}}
            <div class="admin-dashboard-site-traffic__empty-overlay">
              <div class="admin-dashboard-site-traffic__empty-state">
                <span
                  class="admin-dashboard-site-traffic__empty-indicator"
                  aria-hidden="true"
                >
                  <span
                    class="admin-dashboard-site-traffic__empty-indicator-bar"
                  ></span>
                </span>
                <span class="admin-dashboard-site-traffic__empty-text">
                  {{i18n "admin.dashboard.site_traffic.chart.empty"}}
                </span>
              </div>
            </div>
          {{/if}}
        {{else if this.showEmptyState}}
          <div class="admin-dashboard-site-traffic__empty-overlay">
            <div class="admin-dashboard-site-traffic__empty-state">
              <span
                class="admin-dashboard-site-traffic__empty-indicator"
                aria-hidden="true"
              >
                <span
                  class="admin-dashboard-site-traffic__empty-indicator-bar"
                ></span>
              </span>
              <span class="admin-dashboard-site-traffic__empty-text">
                {{i18n "admin.dashboard.site_traffic.chart.empty"}}
              </span>
            </div>
          </div>
        {{/if}}
      </div>

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
                        {{referrer.count}}
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
                        {{country.count}}
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
