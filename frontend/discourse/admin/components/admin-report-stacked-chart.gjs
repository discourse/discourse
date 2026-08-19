import Component from "@glimmer/component";
import Report from "discourse/admin/models/report";
import { buildLegendIcon, dimColor } from "discourse/lib/chart-legend-icon";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
import { remToPx } from "discourse/lib/rem-to-px";
import I18n, { i18n } from "discourse-i18n";
import Chart from "./chart";

function getCSSColor(varName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(varName)
    .trim();
}

function hexToRgba(hex, alpha) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

const emptyTooltipPlugin = {
  id: "emptyTooltipPlugin",
  beforeDraw(chart) {
    const tooltip = chart.tooltip;
    if (!tooltip || tooltip.opacity === 0) {
      return;
    }
    const allZero = tooltip.dataPoints?.every((dp) => !dp.parsed.y);
    if (allZero) {
      tooltip.opacity = 0;
    }
  },
};

const gradientPlugin = {
  id: "gradientPlugin",
  beforeDatasetsDraw(chart) {
    const { ctx } = chart;
    chart.data.datasets.forEach((dataset, datasetIndex) => {
      if (!dataset._baseColor) {
        return;
      }
      const meta = chart.getDatasetMeta(datasetIndex);
      if (!meta.data.length) {
        return;
      }

      const gradients = meta.data.map((bar) => {
        const { x, y, width, base } = bar.getProps(
          ["x", "y", "width", "base"],
          true
        );
        if (!x || !y || !width || !base) {
          return;
        }
        const gradient = ctx.createLinearGradient(
          x - width / 2,
          y,
          x + width / 2,
          base
        );
        gradient.addColorStop(0, dataset._baseColor);
        gradient.addColorStop(1, hexToRgba(dataset._baseColor, 0.7));
        return gradient;
      });

      dataset.backgroundColor = gradients;
    });
  },
};

export function formatTimeScaleTick({
  value,
  timeUnit,
  startDate,
  endDate,
  isFirstTick = false,
}) {
  const date = moment.utc(value);
  const start = moment.utc(startDate);
  const end = moment.utc(endDate);
  const spansYears =
    start.isValid() && end.isValid() && start.year() !== end.year();
  const dateFormat = spansYears ? "D MMM YYYY" : "D MMM";

  if (timeUnit === "month") {
    return date.format("MMM YYYY");
  }
  if (timeUnit === "hour") {
    if (end.diff(start, "days", true) > 2) {
      return isFirstTick || date.hours() === 0 ? date.format(dateFormat) : null;
    }
    return isFirstTick || date.hours() === 0
      ? [date.format(dateFormat), date.format("LT")]
      : date.format("LT");
  }
  return date.format(dateFormat);
}

export default class AdminReportStackedChart extends Component {
  get chartConfig() {
    const { model, options } = this.args;

    const chartOptions = options || {};
    chartOptions.hiddenLabels ??= [];

    const sourceData = makeArray(model.chartData || model.data);
    const chartGrouping =
      chartOptions.chartGrouping ||
      Report.groupingForDatapoints(sourceData[0]?.data?.length || 0);

    const chartData = sourceData.map((series) => ({
      label: series.label,
      color: series.color,
      data: Report.collapse(model, series.data, chartGrouping),
      req: series.req,
    }));

    const data = {
      labels: chartData[0]?.data.map((point) => point.x) ?? [],
      datasets: chartData.map((series) => ({
        label: series.label,
        data: series.data,
        backgroundColor: series.color,
        _baseColor: series.color, // Store for gradient plugin
        hidden: chartOptions.hiddenLabels.includes(series.req),
        borderRadius: 2,
        maxBarThickness: 30,
      })),
    };

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    const timeUnit =
      chartOptions.timeUnit || Report.unitForGrouping(chartGrouping);

    return {
      type: "bar",
      data,
      plugins: [gradientPlugin, emptyTooltipPlugin],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        hover: { mode: "index" },
        animation: {
          duration: prefersReducedMotion ? 0 : 300,
        },
        plugins: {
          legend: {
            display: data.datasets.length > 1,
            position: chartOptions.legendPosition || "bottom",
            onClick: (e, legendItem, legend) => {
              const index = legendItem.datasetIndex;
              const ci = legend.chart;
              const req = chartData[index].req;

              if (chartOptions.onLegendClick) {
                chartOptions.onLegendClick(req);
                return;
              }

              if (ci.isDatasetVisible(index)) {
                ci.hide(index);
                if (!chartOptions.hiddenLabels.includes(req)) {
                  chartOptions.hiddenLabels.push(req);
                }
              } else {
                ci.show(index);
                const hiddenIndex = chartOptions.hiddenLabels.indexOf(req);
                if (hiddenIndex !== -1) {
                  chartOptions.hiddenLabels.splice(hiddenIndex, 1);
                }
              }
            },
            labels: {
              usePointStyle: true,
              padding: remToPx(1),
              font: { size: remToPx(0.75) },
              generateLabels: (chart) => {
                const textColor = getCSSColor("--primary-high");
                return chart.data.datasets.map((dataset, i) => {
                  const isVisible = chart.isDatasetVisible(i);
                  return {
                    text: dataset.label,
                    fontColor: isVisible ? textColor : dimColor(textColor),
                    hidden: false,
                    datasetIndex: i,
                    pointStyle: buildLegendIcon(dataset._baseColor, isVisible),
                  };
                });
              },
            },
          },
          tooltip: {
            mode: "index",
            intersect: false,
            backgroundColor: getCSSColor("--primary"),
            titleColor: getCSSColor("--secondary"),
            bodyColor: getCSSColor("--secondary"),
            footerColor: getCSSColor("--secondary"),
            titleMarginBottom: 16,
            footerMarginTop: 16,
            padding: {
              left: 20,
              right: 20,
              top: 12,
              bottom: 12,
            },
            bodySpacing: 8,
            cornerRadius: 8,
            boxPadding: 4,
            callbacks: {
              beforeFooter: (tooltipItem) => {
                const total = tooltipItem.reduce(
                  (sum, item) => sum + parseInt(item.parsed.y || 0, 10),
                  0
                );
                return i18n("admin.reports.chart.total", {
                  count: I18n.toNumber(total, { precision: 0 }),
                });
              },
              title: (tooltipItem) => this.#tooltipTitle(tooltipItem, timeUnit),
            },
          },
        },

        layout: {
          padding: {
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
          },
        },
        scales: {
          y: {
            stacked: true,
            display: true,
            grid: {
              color: getCSSColor("--primary-very-low"),
              display: !chartOptions.hideYAxisGridLines,
            },
            ticks: {
              callback: (_label, index, ticks) => {
                const value = ticks[index]?.value;
                return Number.isInteger(Number(value)) ? number(value) : null;
              },
              sampleSize: 5,
              maxRotation: 25,
              minRotation: 0,
            },
          },
          x: {
            stacked: true,
            display: true,

            grid: { display: false },
            type: chartOptions.timeScale ? "time" : "category",
            min: chartOptions.timeScale ? model.start_date : undefined,
            max: chartOptions.timeScale ? model.end_date : undefined,
            time: chartOptions.timeScale ? { unit: timeUnit } : undefined,
            ticks: {
              callback: (value, index) =>
                this.#tickLabel(
                  value,
                  data.labels,
                  timeUnit,
                  chartOptions.timeScale,
                  index
                ),
              sampleSize: 5,
              maxRotation: 50,
              minRotation: 0,
              maxTicksLimit: chartOptions.timeScale ? 8 : undefined,
              major: { enabled: chartOptions.timeScale },
            },
          },
        },
      },
    };
  }

  <template>
    <Chart
      ...attributes
      @chartConfig={{this.chartConfig}}
      class="admin-report-chart admin-report-stacked-chart"
    />
  </template>

  #tooltipTitle(tooltipItem, timeUnit) {
    const point = tooltipItem[0].raw;
    const startDate = point?.x ?? tooltipItem[0].parsed.x;

    if (point?.end_date) {
      return this.#tooltipDateRange(startDate, point.end_date);
    }

    return this.#dateLabelMoment(startDate).format(
      timeUnit === "hour" ? "LLL" : "LL"
    );
  }

  #tooltipDateRange(startValue, endValue) {
    const startDate = this.#dateLabelMoment(startValue);
    const endDate = this.#dateLabelMoment(endValue);

    if (startDate.isSame(endDate, "day")) {
      return startDate.format("LL");
    }

    return `${startDate.format("ll")} - ${endDate.format("ll")}`;
  }

  #tickLabel(value, labels, timeUnit, timeScale, index) {
    const label = timeScale ? value : (labels[value] ?? value);

    return this.#formatDateLabel(label, timeUnit, timeScale, index);
  }

  #formatDateLabel(label, timeUnit, timeScale, index) {
    if (timeScale) {
      return formatTimeScaleTick({
        value: label,
        timeUnit,
        startDate: this.args.model.start_date,
        endDate: this.args.model.end_date,
        isFirstTick: index === 0,
      });
    }

    const date = this.#dateLabelMoment(label);

    if (timeUnit === "month") {
      return date.format("MMM YYYY");
    }

    if (timeUnit === "hour") {
      return date.format("D MMM, LT");
    }

    return date.format("D MMM");
  }

  #dateLabelMoment(value) {
    return typeof value === "string" ? moment.utc(value) : moment(value);
  }
}
