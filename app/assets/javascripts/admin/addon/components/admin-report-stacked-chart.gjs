import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import { number } from "discourse/lib/formatter";
import loadScript from "discourse/lib/load-script";
import discourseDebounce from "discourse-common/lib/debounce";
import { makeArray } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";
import Report from "admin/models/report";

export default class AdminReportStackedChart extends Component {
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

    const data = {
      labels: chartData[0].data.mapBy("x"),
      datasets: chartData.map((cd) => ({
        label: cd.label,
        stack: "pageviews-stack",
        data: cd.data,
        backgroundColor: cd.color,
      })),
    };

    return {
      type: "bar",
      data,
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
                  (sum, item) => sum + parseInt(item.parsed.y || 0, 10)
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
                unit: Report.unitForDatapoints(data.labels.length),
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
    <div class="admin-report-chart admin-report-stacked-chart">
      <div class="chart-canvas-container">
        <canvas {{this.renderChart}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
