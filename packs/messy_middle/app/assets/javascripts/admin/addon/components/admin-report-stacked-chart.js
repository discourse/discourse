import { classNames } from "@ember-decorators/component";
import Report from "admin/models/report";
import Component from "@ember/component";
import discourseDebounce from "discourse-common/lib/debounce";
import loadScript from "discourse/lib/load-script";
import { makeArray } from "discourse-common/lib/helpers";
import { number } from "discourse/lib/formatter";
import { schedule } from "@ember/runloop";
import { bind } from "discourse-common/utils/decorators";

@classNames("admin-report-chart", "admin-report-stacked-chart")
export default class AdminReportStackedChart extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    window.addEventListener("resize", this._resizeHandler);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    window.removeEventListener("resize", this._resizeHandler);
    this._resetChart();
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    discourseDebounce(this, this._scheduleChartRendering, 100);
  }

  @bind
  _resizeHandler() {
    discourseDebounce(this, this._scheduleChartRendering, 500);
  }

  _scheduleChartRendering() {
    schedule("afterRender", () => {
      if (!this.element) {
        return;
      }

      this._renderChart(
        this.model,
        this.element.querySelector(".chart-canvas")
      );
    });
  }

  _renderChart(model, chartCanvas) {
    if (!chartCanvas) {
      return;
    }

    const context = chartCanvas.getContext("2d");

    const chartData = makeArray(model.chartData || model.data).map((cd) => {
      return {
        label: cd.label,
        color: cd.color,
        data: Report.collapse(model, cd.data),
      };
    });

    const data = {
      labels: chartData[0].data.mapBy("x"),
      datasets: chartData.map((cd) => {
        return {
          label: cd.label,
          stack: "pageviews-stack",
          data: cd.data,
          backgroundColor: cd.color,
        };
      }),
    };

    loadScript("/javascripts/Chart.min.js").then(() => {
      this._resetChart();

      this._chart = new window.Chart(context, this._buildChartConfig(data));
    });
  }

  _buildChartConfig(data) {
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
                let total = 0;
                tooltipItem.forEach(
                  (item) => (total += parseInt(item.parsed.y || 0, 10))
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

  _resetChart() {
    this._chart?.destroy();
    this._chart = null;
  }
}
