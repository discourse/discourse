import Component from "@glimmer/component";
import Report from "discourse/admin/models/report";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
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
        // Diagonal gradient from top-left to bottom-right of each bar
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
        data: Report.collapse(model, series.data, chartOptions.chartGrouping),
        req: series.req,
      })
    );

    const data = {
      labels: chartData[0].data.map((point) => point.x),
      datasets: chartData.map((series) => ({
        label: series.label,
        stack: "pageviews-stack",
        data: series.data,
        backgroundColor: series.color,
        _baseColor: series.color, // Store for gradient plugin
        hidden: chartOptions.hiddenLabels.includes(series.req),
        borderRadius: 2,
        maxBarThickness: 30,
      })),
    };

    return {
      type: "bar",
      data,
      plugins: [gradientPlugin],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        responsiveAnimationDuration: 0,
        hover: { mode: "index" },
        animation: {
          duration: 0,
        },
        plugins: {
          legend: {
            display: true,
            position: "bottom",
            labels: {
              usePointStyle: true,
              pointStyle: "rectRounded",
              padding: 25,
              boxWidth: 10,
              boxHeight: 10,
              generateLabels: (chart) => {
                const textColor = getCSSColor("--primary-high");
                return chart.data.datasets.map((dataset, i) => {
                  const isVisible = chart.isDatasetVisible(i);
                  return {
                    text: dataset.label,
                    fontColor: textColor,
                    fillStyle: isVisible ? dataset._baseColor : "transparent",
                    strokeStyle: dataset._baseColor,
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
            callbacks: {
              beforeFooter: (tooltipItem) => {
                const total = tooltipItem.reduce(
                  (sum, item) => sum + parseInt(item.parsed.y || 0, 10),
                  0
                );
                return `= ${total}`;
              },
              title: (tooltipItem) =>
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
            },
          },
          x: {
            stacked: true,
            display: true,

            grid: { display: false },
            type: "time",
            time: {
              unit: chartOptions.chartGrouping
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
      @chartConfig={{this.chartConfig}}
      class="admin-report-chart admin-report-stacked-chart"
    />
  </template>
}
