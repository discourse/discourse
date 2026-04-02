import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { bind } from "discourse/lib/decorators";
import loadChartJS from "discourse/lib/load-chart-js";
import { SERIES_COLORS } from "../lib/chart-helpers";
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
    const primaryColor = themeColor("--tertiary");

    const dataset = {
      label: this.args.datasets[0].label,
      data: this.args.datasets[0].values,
      backgroundColor: isLine ? "transparent" : primaryColor,
      borderColor: primaryColor,
      borderWidth: isLine ? 2 : 0,
      pointRadius: isLine ? 2 : 0,
      pointHoverRadius: isLine ? 4 : 0,
      tension: 0.3,
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
        maintainAspectRatio: true,
        plugins: {
          legend: { display: false },
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

    const datasets = this.args.datasets.map((ds, i) => {
      const color = SERIES_COLORS[i % SERIES_COLORS.length];
      const result = {
        label: ds.label,
        data: ds.values,
        backgroundColor: color,
        borderColor: color,
        borderWidth: 1,
      };

      if (stacked) {
        result.stack = "data-explorer-stack";
      }

      return result;
    });

    const xTicks = { color: labelColor };
    if (stacked) {
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

    return {
      type: "bar",
      data: { labels: this.args.labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          legend: { display: true, position: "bottom" },
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: stacked
              ? {
                  beforeFooter(items) {
                    const total = items.reduce(
                      (sum, item) => sum + (item.parsed.y || 0),
                      0
                    );
                    return `Total: ${total.toLocaleString()}`;
                  },
                }
              : {},
          },
        },
        scales,
      },
    };
  }

  @bind
  async initChart(canvas) {
    const Chart = await loadChartJS();
    const context = canvas.getContext("2d");
    this.chart = new Chart(context, this.config);
  }

  @action
  updateChartData() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.initChart(this.chart?.canvas);
  }

  <template>
    <canvas {{didInsert this.initChart}}></canvas>
  </template>
}
