import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { buildLegendIcon, dimColor } from "discourse/lib/chart-legend-icon";
import { bind } from "discourse/lib/decorators";
import loadChartJS from "discourse/lib/load-chart-js";
import { remToPx } from "discourse/lib/rem-to-px";
import I18n, { i18n } from "discourse-i18n";
import { formatChartDateLabel, SERIES_COLORS } from "../lib/chart-helpers";
import themeColor from "../lib/themeColor";

export default class DataExplorerChart extends Component {
  chart;

  willDestroy() {
    super.willDestroy(...arguments);
    this.chart?.destroy();
  }

  get config() {
    const gridColor = themeColor("--primary-low");
    const labelColor = themeColor("--primary-medium");

    if (this.args.datasets.length > 1) {
      return this._buildMultiSeriesConfig(gridColor, labelColor);
    }

    return this._buildSingleSeriesConfig(gridColor, labelColor);
  }

  _buildSingleSeriesConfig(gridColor, labelColor) {
    const isLine = this.args.chartType === "line";
    const tertiaryRgb = themeColor("--tertiary-rgb");
    const primaryColor = `rgb(${tertiaryRgb})`;
    const secondaryColor = `rgba(${tertiaryRgb}, 0.1)`;

    // mirror core's admin report chart so data explorer charts render
    // identically on the dashboard and the data explorer page
    const dataset = {
      label: this.args.datasets[0].label,
      data: this.args.datasets[0].values,
      backgroundColor: isLine ? secondaryColor : primaryColor,
      borderColor: primaryColor,
      borderWidth: isLine ? 2 : 0,
      pointRadius: isLine ? 3 : 0,
      pointHoverRadius: isLine ? 4 : 0,
      pointBackgroundColor: primaryColor,
      pointBorderColor: primaryColor,
      pointStyle: "rectRounded",
      borderCapStyle: "round",
      borderJoinStyle: "round",
      tension: 0.4,
      fill: isLine ? "origin" : false,
    };

    const xTicks = { color: labelColor };
    if (isLine) {
      xTicks.maxTicksLimit = 8;
    }

    return {
      type: this.args.chartType,
      data: { labels: this.args.labels, datasets: [dataset] },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: themeColor("--primary"),
            titleColor: themeColor("--secondary"),
            bodyColor: themeColor("--secondary"),
            titleMarginBottom: 16,
            padding: { left: 20, right: 20, top: 12, bottom: 12 },
            bodySpacing: 8,
            cornerRadius: 8,
            boxPadding: 4,
            callbacks: {
              title: (items) => {
                const label = items[0].label;
                return formatChartDateLabel(label);
              },
              label: (item) => item.formattedValue,
            },
          },
        },
        scales: {
          x: {
            ticks: xTicks,
            grid: { display: false },
          },
          y: {
            ticks: { color: labelColor },
            grid: { color: gridColor },
            beginAtZero: true,
          },
        },
      },
    };
  }

  _buildMultiSeriesConfig(gridColor, labelColor) {
    const stacked = this.args.stacked;
    const isLine = this.args.chartType === "line";
    const dualAxis = this.args.dualAxis;

    const datasets = this.args.datasets.map((ds, i) => {
      const color = SERIES_COLORS[i % SERIES_COLORS.length];
      const result = {
        label: ds.label,
        data: ds.values,
        backgroundColor: isLine ? "transparent" : color,
        borderColor: color,
        borderWidth: isLine ? 2 : 1,
      };

      if (dualAxis) {
        result.yAxisID = i === 0 ? "y" : "y1";
        if (i > 0) {
          result.borderDash = [5, 5];
        }
      }

      if (stacked) {
        result.stack = "data-explorer-stack";
      }

      if (isLine) {
        result.pointRadius = 2;
        result.pointHoverRadius = 4;
        result.pointBackgroundColor = color;
        result.pointBorderColor = color;
        result.pointStyle = "rectRounded";
        result.borderCapStyle = "round";
        result.borderJoinStyle = "round";
        result.tension = 0.4;
        result.fill = false;
      }

      return result;
    });

    const xTicks = { color: labelColor };
    if (stacked || isLine) {
      xTicks.maxTicksLimit = 8;
    }

    const scales = {
      x: {
        ticks: xTicks,
        grid: { display: false },
      },
      y: {
        ticks: { color: labelColor },
        grid: { color: gridColor },
        beginAtZero: true,
      },
    };

    if (stacked) {
      scales.x.stacked = true;
      scales.y.stacked = true;
    }

    if (dualAxis) {
      scales.y1 = {
        type: "linear",
        position: "right",
        ticks: { color: labelColor },
        grid: { drawOnChartArea: false },
        beginAtZero: true,
      };
    }

    return {
      type: this.args.chartType,
      data: { labels: this.args.labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: "bottom",
            labels: {
              usePointStyle: true,
              padding: remToPx(1),
              font: { size: remToPx(0.75) },
              generateLabels: (chart) =>
                chart.data.datasets.map((dataset, i) => {
                  const isVisible = chart.isDatasetVisible(i);
                  return {
                    text: dataset.label,
                    fontColor: isVisible ? labelColor : dimColor(labelColor),
                    hidden: false,
                    datasetIndex: i,
                    pointStyle: buildLegendIcon(dataset.borderColor, isVisible),
                  };
                }),
            },
          },
          tooltip: this._multiSeriesTooltipOptions(stacked),
        },
        scales,
      },
    };
  }

  _multiSeriesTooltipOptions(stacked) {
    const callbacks = {
      title: (items) => {
        const label = items[0].label;
        return formatChartDateLabel(label);
      },
    };

    if (stacked) {
      callbacks.beforeFooter = (items) => {
        const total = items.reduce(
          (sum, item) => sum + (item.parsed.y || 0),
          0
        );

        return i18n("explorer.chart.tooltip.total", {
          count: I18n.toNumber(total, { precision: 0 }),
        });
      };
    }

    return {
      mode: "index",
      intersect: false,
      callbacks,
    };
  }

  @bind
  async initChart(canvas) {
    const Chart = await loadChartJS();
    const context = canvas.getContext("2d");
    this.chart = new Chart(context, this.config);
  }

  @action
  updateChartData(canvas) {
    if (this.chart) {
      this.chart.destroy();
    }
    this.initChart(canvas);
  }

  <template>
    <canvas
      {{didInsert this.initChart}}
      {{didUpdate
        this.updateChartData
        @labels
        @datasets
        @chartType
        @stacked
        @dualAxis
      }}
    ></canvas>
  </template>
}
