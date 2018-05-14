import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";
import AsyncReport from "admin/mixins/async-report";
import Report from "admin/models/report";
import { number } from 'discourse/lib/formatter';

function collapseWeekly(data, average) {
  let aggregate = [];
  let bucket, i;
  let offset = data.length % 7;
  for(i = offset; i < data.length; i++) {

    if (bucket && (i % 7 === offset)) {
      if (average) {
        bucket.y = parseFloat((bucket.y / 7.0).toFixed(2));
      }
      aggregate.push(bucket);
      bucket = null;
    }

    bucket = bucket || { x: data[i].x, y: 0 };
    bucket.y += data[i].y;
  }
  return aggregate;
}

export default Ember.Component.extend(AsyncReport, {
  classNames: ["dashboard-mini-chart"],
  classNameBindings: ["trend", "oneDataPoint"],
  isLoading: true,
  trend: Ember.computed.alias("report.trend"),
  oneDataPoint: false,
  backgroundColor: "rgba(200,220,240,0.3)",
  borderColor: "#08C",
  average: false,
  total: 0,

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

  fetchReport() {
    this.set("isLoading", true);

    let payload = {
      data: { async: true, facets: ["prev_period"] }
    };

    if (this.get("startDate")) {
      payload.data.start_date = this.get("startDate").locale('en').format('YYYY-MM-DD[T]HH:mm:ss.SSSZZ');
    }

    if (this.get("endDate")) {
      payload.data.end_date = this.get("endDate").locale('en').format('YYYY-MM-DD[T]HH:mm:ss.SSSZZ');
    }

    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }

    this.set("report", null);

    ajax(this.get("dataSource"), payload)
      .then((response) => {
        this.set('reportKey', response.report.report_key);
        this.loadReport(response.report);
      })
      .finally(() => {
        if (this.get("oneDataPoint")) {
          this.set("isLoading", false);
          return;
        }

        if (!Ember.isEmpty(this.get("report.data"))) {
          this.set("isLoading", false);
          this.renderReport();
        }
      });
  },

  loadReport(report) {
    if (_.isArray(report.data)) {
      Report.fillMissingDates(report);

      if (report.data && report.data.length > 40) {
        report.data = collapseWeekly(report.data, this.get("average"));
      }

      const model = Report.create(report);
      this._setPropertiesFromReport(model);
    }
  },

  renderReport() {
    if (!this.element || this.isDestroying || this.isDestroyed) { return; }
    if (this.get("oneDataPoint")) return;

    Ember.run.schedule("afterRender", () => {
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

      if (this._chart) {
        this._chart.destroy();
      }
      this._chart = new window.Chart(context, this._buildChartConfig(data));
    });
  },

  _setPropertiesFromReport(report) {
    const oneDataPoint = (this.get("startDate") && this.get("endDate")) &&
      this.get("startDate").isSame(this.get("endDate"), "day");

    report.set("average", this.get("average"));
    this.setProperties({ oneDataPoint, report });
  },

  _buildChartConfig(data) {
    return {
      type: "line",
      data,
      options: {
        legend: {
          display: false
        },
        responsive: true,
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
            ticks: { callback: (label) => number(label) }
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
