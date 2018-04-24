import { ajax } from 'discourse/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';
import loadScript from 'discourse/lib/load-script';

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
    this._initializeChart();
  },

  didUpdateAttrs() {
    this._super();
    this._initializeChart();
  },

  @computed("dataSourceName")
  dataSource(dataSourceName) {
    if (dataSourceName) {
      return `/admin/reports/${dataSourceName}`;
    }
  },

  @computed("trend")
  trendIcon(trend) {
    if (trend === "stable") {
      return null;
    } else {
      return `angle-${trend}`;
    }
  },

  _fetchReport() {
    if (this.get("isLoading")) return;

    this.set("isLoading", true);

    let payload = {data: {}};

    if (this.get("startDate")) {
      payload.data.start_date = this.get("startDate").toISOString();
    }

    if (this.get("endDate")) {
      payload.data.end_date = this.get("endDate").toISOString();
    }

    ajax(this.get("dataSource"), payload)
      .then((response) => {
        this._setPropertiesFromModel(response.report);
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

  _initializeChart() {
    loadScript("/javascripts/Chart.min.js").then(() => {
      if (this.get("model") && !this.get("values")) {
        this._setPropertiesFromModel(this.get("model"));
        this._drawChart();
      } else if (this.get("dataSource")) {
        this._fetchReport();
      }
    });
  },

  _drawChart() {
    const $chartCanvas = this.$(".chart-canvas");
    if (!$chartCanvas.length) return;

    const context = $chartCanvas[0].getContext("2d");

    const data = {
      labels: this.get("labels"),
      datasets: [{
        data: this.get("values"),
        backgroundColor: this.get("backgroundColor"),
        borderColor: this.get("borderColor")
      }]
    };

    this._chart = new window.Chart(context, this._buildChartConfig(data));
  },

  _setPropertiesFromModel(model) {
    this.setProperties({
      labels: model.data.map(r => r.x),
      values: model.data.map(r => r.y),
      oneDataPoint: (this.get("startDate") && this.get("endDate")) &&
                    this.get("startDate").isSame(this.get("endDate"), 'day'),
      total: model.total,
      title: model.title,
      trend: this._computeTrend(model.total, model.prev30Days)
    });
  },

  _buildChartConfig(data) {
    const values = this.get("values");
    const max = Math.max(...values);
    const min = Math.min(...values);
    const stepSize = Math.max(...[Math.ceil((max - min)/5), 20]);

    const startDate = this.get("startDate") || moment();
    const endDate = this.get("endDate") || moment();
    const datesDifference = startDate.diff(endDate, "days");
    let unit = "day";
    if (datesDifference >= 366) {
      unit = "quarter";
    } else if (datesDifference >= 61) {
      unit = "month";
    } else if (datesDifference >= 14) {
      unit = "week";
    }

    return {
      type: "line",
      data,
      options: {
        legend: { display: false },
        responsive: true,
        layout: { padding: { left: 0, top: 0, right: 0, bottom: 0 } },
        scales: {
          yAxes: [
            {
              display: true,
              ticks: { suggestedMin: 0, stepSize, suggestedMax: max + stepSize }
            }
          ],
          xAxes: [
            {
              display: true,
              type: "time",
              time: {
                parser: "YYYY-MM-DD",
                unit
              }
            }
          ],
        }
      },
    };
  },

  _computeTrend(total, prevTotal) {
    const percentChange = ((total - prevTotal) / prevTotal) * 100;

    if (percentChange > 50) return "double-up";
    if (percentChange > 0) return "up";
    if (percentChange === 0) return "stable";
    if (percentChange < 50) return "double-down";
    if (percentChange < 0) return "down";
  },
});
