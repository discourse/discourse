import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import { number } from "discourse/lib/formatter";
import loadScript from "discourse/lib/load-script";
import discourseDebounce from "discourse-common/lib/debounce";
import { makeArray } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";
import Report from "admin/models/report";

function hexToRGBA(hexCode, opacity) {
  let hex = hexCode.replace("#", "");

  if (hex.length === 3) {
    hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
  }

  const r = parseInt(hex.substring(0, 2), 16),
    g = parseInt(hex.substring(2, 4), 16),
    b = parseInt(hex.substring(4, 6), 16);

  return `rgba(${r},${g},${b}, ${opacity})`;
}

export default class AdminReportStackedLineChart extends Component {
  @tracked rerenderTrigger;

  renderChart = modifier((element) => {
    // consume the prop to re-run the modifier when the prop changes
    this.rerenderTrigger;

    loadScript("/javascripts/Chart.min.js").then(() => {
      this.chart = new window.Chart(element.getContext("2d"), this.chartConfig);
    });

    return () => this.chart?.destroy();
  });

  constructor() {
    super(...arguments);
    window.addEventListener("resize", this.resizeHandler);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("resize", this.resizeHandler);
  }

  @bind
  resizeHandler() {
    discourseDebounce(this, this.rerenderChart, 500);
  }

  rerenderChart() {
    this.rerenderTrigger = true;
  }

  get chartConfig() {
    const { model } = this.args;

    const chartData = makeArray(model.chartData || model.data).map((cd) => ({
      label: cd.label,
      color: cd.color,
      data: Report.collapse(model, cd.data),
    }));

    return {
      type: "line",
      data: {
        labels: chartData[0].data.mapBy("x"),
        datasets: chartData.map((cd) => ({
          label: cd.label,
          stack: "pageviews-stack",
          data: cd.data,
          fill: true,
          backgroundColor: hexToRGBA(cd.color, 0.3),
          borderColor: cd.color,
          pointBackgroundColor: cd.color,
          pointBorderColor: "#fff",
          pointHoverBackgroundColor: "#fff",
          pointHoverBorderColor: cd.color,
        })),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        responsiveAnimationDuration: 0,
        hover: { mode: "index" },
        animation: {
          duration: 0,
        },
        plugins: {
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
                moment(tooltipItem[0].label, "YYYY-MM-DD").format("LL"),
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
          y: [
            {
              stacked: true,
              display: true,
              ticks: {
                callback: (label) => number(label),
                sampleSize: 5,
                maxRotation: 25,
                minRotation: 25,
              },
            },
          ],
          x: [
            {
              display: true,
              gridLines: { display: false },
              type: "time",
              time: {
                unit: Report.unitForDatapoints(chartData[0].data.length),
              },
              ticks: {
                sampleSize: 5,
                maxRotation: 50,
                minRotation: 50,
              },
            },
          ],
        },
      },
    };
  }

  <template>
    <div class="admin-report-chart admin-report-stacked-line-chart">
      <div class="chart-canvas-container">
        <canvas {{this.renderChart}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
