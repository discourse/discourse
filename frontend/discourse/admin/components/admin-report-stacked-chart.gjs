import Component from "@glimmer/component";
import Report from "discourse/admin/models/report";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
import Chart from "./chart";

function getCSSColor(varName, element = document.documentElement) {
  return getComputedStyle(element).getPropertyValue(varName).trim();
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

export default class AdminReportStackedChart extends Component {
  get chartConfig() {
    const { model, options } = this.args;

    const chartOptions = options || {};
    chartOptions.hiddenLabels ??= [];

    const chartData = makeArray(model.chartData || model.data).map(
      (series) => ({
        label: series.label,
        color: series.color,
        colorVar: series.color_var,
        data: chartOptions.skipCollapse
          ? series.data
          : Report.collapse(model, series.data, chartOptions.chartGrouping),
        req: series.req,
      })
    );

    const data = {
      labels: chartData[0]?.data.map((point) => point.x) ?? [],
      datasets: chartData.map((series) => ({
        label: series.label,
        stack: chartOptions.stack || "pageviews-stack",
        data: series.data,
        backgroundColor:
          series.color ||
          ((context) => this.#seriesColor(series, context.chart.canvas)),
        _baseColor: series.color,
        _colorVar: series.colorVar,
        hidden: chartOptions.hiddenLabels.includes(series.req),
        borderRadius: chartOptions.borderRadius ?? 2,
        maxBarThickness: chartOptions.maxBarThickness ?? 30,
      })),
    };

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    return {
      type: "bar",
      data,
      plugins:
        chartOptions.useGradient === false
          ? [emptyTooltipPlugin]
          : [gradientPlugin, emptyTooltipPlugin],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        hover: { mode: "index", intersect: false },
        animation: {
          duration: prefersReducedMotion ? 0 : 300,
        },
        plugins: {
          legend: {
            display: chartOptions.legendDisplay ?? true,
            position: chartOptions.legendPosition || "bottom",
            align: chartOptions.legendAlign,
            onClick: (e, legendItem, legend) => {
              const index = legendItem.datasetIndex;
              const ci = legend.chart;
              const req = chartData[index].req;

              if (ci.isDatasetVisible(index)) {
                ci.hide(index);
                if (!chartOptions.hiddenLabels.includes(req)) {
                  chartOptions.hiddenLabels.push(req);
                }
              } else {
                ci.show(index);
                chartOptions.hiddenLabels = chartOptions.hiddenLabels.filter(
                  (l) => l !== req
                );
              }
            },
            labels: {
              usePointStyle: true,
              pointStyle: "rectRounded",
              ...this.#legendPadding(chartOptions),
              boxWidth: 10,
              boxHeight: 10,
              generateLabels: (chart) => {
                const textColor = getCSSColor("--primary-high");
                return chart.data.datasets.map((dataset, i) => {
                  const isVisible = chart.isDatasetVisible(i);
                  const color = this.#seriesColor(dataset, chart.canvas);

                  return {
                    text: dataset.label,
                    fontColor: textColor,
                    fillStyle: isVisible ? color : "transparent",
                    strokeStyle: color,
                    lineWidth: 2,
                    hidden: false,
                    datasetIndex: i,
                    pointStyle: "rectRounded",
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
                return `Total: ${total}`;
              },
              title: (tooltipItem) =>
                chartOptions.tooltipTitle?.(tooltipItem) ||
                moment(tooltipItem[0].parsed.x).format("LL"),
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
            },
            ticks: {
              callback: (label) => number(label),
              sampleSize: 5,
              maxRotation: 25,
              minRotation: 0,
              stepSize: 1,
            },
          },
          x: {
            stacked: true,
            display: true,

            grid: { display: false },
            type: "time",
            time: {
              unit: chartOptions.timeUnit
                ? chartOptions.timeUnit
                : chartOptions.chartGrouping
                  ? Report.unitForGrouping(chartOptions.chartGrouping)
                  : Report.unitForDatapoints(data.labels.length),
            },
            ticks: {
              sampleSize: 5,
              maxRotation: 50,
              minRotation: 0,
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
      @rebuildKey={{@rebuildKey}}
      class="admin-report-chart admin-report-stacked-chart"
    />
  </template>

  #seriesColor(series, element = document.documentElement) {
    if (series.color || series._baseColor) {
      return series.color || series._baseColor;
    }

    if (series.colorVar || series._colorVar) {
      return (
        getCSSColor(series.colorVar || series._colorVar, element) ||
        getCSSColor("--primary-med-or-secondary-med", element)
      );
    }

    return getCSSColor("--primary-med-or-secondary-med", element);
  }

  #legendPadding(chartOptions) {
    if (chartOptions.legendLabelPadding === null) {
      return {};
    }

    return { padding: chartOptions.legendLabelPadding ?? 25 };
  }
}
