import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";
import loadScript from "discourse/lib/load-script";
import Report from "admin/models/report";

export default Ember.Component.extend({
  classNames: ["dashboard-mini-chart"],

  classNameBindings: ["trend", "oneDataPoint", "isLoading"],

  isLoading: false,
  total: null,
  trend: null,
  title: null,
  oneDataPoint: false,
  backgroundColor: "rgba(200,220,240,0.3)",
  borderColor: "#08C",

  didInsertElement() {
    this._super();

    if (this.get("model")) {
      loadScript("/javascripts/Chart.min.js").then(() => {
        this._setPropertiesFromModel(this.get("model"));
        this._drawChart();
      });
    }
  },

  didUpdateAttrs() {
    this._super();

    loadScript("/javascripts/Chart.min.js").then(() => {
      if (this.get("model") && !this.get("values")) {
        this._setPropertiesFromModel(this.get("model"));
        this._drawChart();
      } else if (this.get("dataSource")) {
        this._fetchReport();
      }
    });
  },

  @computed("dataSourceName")
  dataSource(dataSourceName) {
    if (dataSourceName) {
      return `/admin/reports/${dataSourceName}`;
    }
  },

  @computed("trend")
  trendIcon(trend) {
    switch (trend) {
      case "trending-up":
        return "angle-up";
      case "trending-down":
        return "angle-down";
      case "high-trending-up":
        return "angle-double-up";
      case "high-trending-down":
        return "angle-double-down";
      default:
        return null;
    }
  },

  _fetchReport() {
    if (this.get("isLoading")) return;

    this.set("isLoading", true);

    let payload = {
      data: {}
    };

    if (this.get("startDate")) {
      payload.data.start_date = this.get("startDate").toISOString();
    }

    if (this.get("endDate")) {
      payload.data.end_date = this.get("endDate").toISOString();
    }

    ajax(this.get("dataSource"), payload)
      .then((response) => {
        this._setPropertiesFromModel(Report.create(response.report));
      })
      .finally(() => {
        this.set("isLoading", false);

        Ember.run.schedule("afterRender", () => {
          if (!this.get("oneDataPoint")) {
            this._drawChart();
          }
        });
      });
  },

  _drawChart() {
    const $chartCanvas = this.$(".chart-canvas");
    if (!$chartCanvas.length) return;

    const context = $chartCanvas[0].getContext("2d");

    const data = {
      labels: this.get("labels"),
      datasets: [{
        data: Ember.makeArray(this.get("values")),
        backgroundColor: this.get("backgroundColor"),
        borderColor: this.get("borderColor")
      }]
    };

    this._chart = new window.Chart(context, this._buildChartConfig(data));
  },

  _setPropertiesFromModel(report) {
    const oneDataPoint = (this.get("startDate") && this.get("endDate")) &&
      this.get("startDate").isSame(this.get("endDate"), "day");

    this.setProperties({
      oneDataPoint,
      labels: report.get("data").map(r => r.x),
      values: report.get("data").map(r => r.y),
      total: report.get("total"),
      description: report.get("description"),
      title: report.get("title"),
      trend: report.get("sevenDayTrend"),
      prev30Days: report.get("prev30Days"),
    });
  },

  _buildChartConfig(data) {
    const values = data.datasets[0].data;
    const max = Math.max(...values);
    const min = Math.min(...values);

    const stepSize = Math.max(...[Math.ceil((max - min) / 5) * 5, 20]);

    return {
      type: "line",
      data,
      options: {
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
          yAxes: [{
            display: true,
            ticks: {
              suggestedMin: 0,
              stepSize,
              suggestedMax: max + stepSize
            }
          }],
          xAxes: [{
            display: true,
            type: "time",
            time: {
              parser: "YYYY-MM-DD"
            }
          }],
        }
      },
    };
  }
});
