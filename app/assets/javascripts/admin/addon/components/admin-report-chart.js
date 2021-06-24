import Report from "admin/models/report";
import Component from "@ember/component";
import discourseDebounce from "discourse-common/lib/debounce";
import loadScript from "discourse/lib/load-script";
import { makeArray } from "discourse-common/lib/helpers";
import { number } from "discourse/lib/formatter";
import { schedule } from "@ember/runloop";

export default Component.extend({
  classNames: ["admin-report-chart"],
  limit: 8,
  total: 0,
  options: null,

  init() {
    this._super(...arguments);

    this.resizeHandler = () =>
      discourseDebounce(this, this._scheduleChartRendering, 500);
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

    discourseDebounce(this, this._scheduleChartRendering, 100);
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
    if (!chartCanvas) {
      return;
    }

    const context = chartCanvas.getContext("2d");
    const chartData = this._applyChartGrouping(
      model,
      makeArray(model.get("chartData") || model.get("data"), "weekly"),
      this.options
    );
    const prevChartData = makeArray(
      model.get("prevChartData") || model.get("prev_data")
    );

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

    loadScript("/javascripts/Chart.min.js").then(() => {
      this._resetChart();

      if (!this.element) {
        return;
      }

      this._chart = new window.Chart(
        context,
        this._buildChartConfig(data, this.options)
      );
    });
  },

  _buildChartConfig(data, options) {
    return {
      type: "line",
      data,
      options: {
        tooltips: {
          callbacks: {
            title: (tooltipItem) =>
              moment(tooltipItem[0].xLabel, "YYYY-MM-DD").format("LL"),
          },
        },
        legend: {
          display: false,
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
          yAxes: [
            {
              display: true,
              ticks: {
                userCallback: (label) => {
                  if (Math.floor(label) === label) {
                    return label;
                  }
                },
                callback: (label) => number(label),
                sampleSize: 5,
                maxRotation: 25,
                minRotation: 25,
              },
            },
          ],
          xAxes: [
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
  },

  _resetChart() {
    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }
  },

  _applyChartGrouping(model, data, options) {
    return Report.collapse(model, data, options.chartGrouping);
  },
});
