import { debounce } from "@ember/runloop";
import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import { number } from "discourse/lib/formatter";
import loadScript from "discourse/lib/load-script";

export default Component.extend({
  classNames: ["admin-report-chart"],
  limit: 8,
  total: 0,

  init() {
    this._super(...arguments);

    this.resizeHandler = () =>
      debounce(this, this._scheduleChartRendering, 500);
  },

  didInsertElement() {
    this._super(...arguments);

    $(window).on("resize.chart", this.resizeHandler);
  },

  willDestroyElement() {
    this._super(...arguments);

    $(window).off("resize.chart", this.resizeHandler);

    this._resetChart();
  },

  didReceiveAttrs() {
    this._super(...arguments);

    debounce(this, this._scheduleChartRendering, 100);
  },

  _scheduleChartRendering() {
    schedule("afterRender", () => {
      this._renderChart(
        this.model,
        this.element && this.element.querySelector(".chart-canvas")
      );
    });
  },

  _renderChart(model, chartCanvas) {
    if (!chartCanvas) return;

    const context = chartCanvas.getContext("2d");
    const chartData = Ember.makeArray(
      model.get("chartData") || model.get("data")
    );
    const prevChartData = Ember.makeArray(
      model.get("prevChartData") || model.get("prev_data")
    );

    const labels = chartData.map(d => d.x);

    const data = {
      labels,
      datasets: [
        {
          data: chartData.map(d => Math.round(parseFloat(d.y))),
          backgroundColor: prevChartData.length
            ? "transparent"
            : model.secondary_color,
          borderColor: model.primary_color,
          pointRadius: 3,
          borderWidth: 1,
          pointBackgroundColor: model.primary_color,
          pointBorderColor: model.primary_color
        }
      ]
    };

    if (prevChartData.length) {
      data.datasets.push({
        data: prevChartData.map(d => Math.round(parseFloat(d.y))),
        borderColor: model.primary_color,
        borderDash: [5, 5],
        backgroundColor: "transparent",
        borderWidth: 1,
        pointRadius: 0
      });
    }

    loadScript("/javascripts/Chart.min.js").then(() => {
      this._resetChart();
      this._chart = new window.Chart(context, this._buildChartConfig(data));
    });
  },

  _buildChartConfig(data) {
    return {
      type: "line",
      data,
      options: {
        tooltips: {
          callbacks: {
            title: tooltipItem =>
              moment(tooltipItem[0].xLabel, "YYYY-MM-DD").format("LL")
          }
        },
        legend: {
          display: false
        },
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            left: 0,
            top: 0,
            right: 0,
            bottom: 0
          }
        },
        scales: {
          yAxes: [
            {
              display: true,
              ticks: {
                userCallback: label => {
                  if (Math.floor(label) === label) return label;
                },
                callback: label => number(label)
              }
            }
          ],
          xAxes: [
            {
              display: true,
              gridLines: { display: false },
              type: "time",
              time: {
                parser: "YYYY-MM-DD"
              }
            }
          ]
        }
      }
    };
  },

  _resetChart() {
    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }
  }
});
