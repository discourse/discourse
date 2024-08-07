import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import { number } from "discourse/lib/formatter";
import loadScript from "discourse/lib/load-script";
import discourseDebounce from "discourse-common/lib/debounce";
import { makeArray } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";
import Report from "admin/models/report";

export default class AdminReportChart extends Component {
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
    const { model, options } = this.args;

    const chartData = Report.collapse(
      model,
      makeArray(model.chartData || model.data, "weekly"),
      options.chartGrouping
    );
    const prevChartData = makeArray(model.prevChartData || model.prev_data);
    const labels = chartData.map((d) => d.x);

    const data = {
      labels,
      datasets: [
        {
          data: chartData.map((d) => Math.round(parseFloat(d.y))),
          backgroundColor: prevChartData.length
            ? "transparent"
            : model.secondary_color,
          borderColor: model.primary_color,
          pointRadius: 3,
          borderWidth: 1,
          pointBackgroundColor: model.primary_color,
          pointBorderColor: model.primary_color,
        },
      ],
    };

    if (prevChartData.length) {
      data.datasets.push({
        data: prevChartData.map((d) => Math.round(parseFloat(d.y))),
        borderColor: model.primary_color,
        borderDash: [5, 5],
        backgroundColor: "transparent",
        borderWidth: 1,
        pointRadius: 0,
      });
    }

    return {
      type: "line",
      data,
      options: {
        plugins: {
          tooltip: {
            callbacks: {
              title: (tooltipItem) =>
                moment(tooltipItem[0].label, "YYYY-MM-DD").format("LL"),
            },
          },
          legend: {
            display: false,
          },
        },
        responsive: true,
        maintainAspectRatio: false,
        responsiveAnimationDuration: 0,
        animation: {
          duration: 0,
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
                unit: Report.unitForGrouping(options.chartGrouping),
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
    <div class="admin-report-chart">
      <div class="chart-canvas-container">
        <canvas {{this.renderChart}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
