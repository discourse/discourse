import { ajax } from "discourse/lib/ajax";
import AsyncReport from "admin/mixins/async-report";
import Report from "admin/models/report";
import { number } from "discourse/lib/formatter";
import loadScript from "discourse/lib/load-script";
import { registerTooltip, unregisterTooltip } from "discourse/lib/tooltip";

function collapseWeekly(data, average) {
  let aggregate = [];
  let bucket, i;
  let offset = data.length % 7;
  for (i = offset; i < data.length; i++) {
    if (bucket && i % 7 === offset) {
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
  classNames: ["chart", "dashboard-mini-chart"],
  total: 0,

  init() {
    this._super();

    this._colorsPool = ["rgb(0,136,204)", "rgb(235,83,148)"];
  },

  didRender() {
    this._super();
    registerTooltip($(this.element).find("[data-tooltip]"));
  },

  willDestroyElement() {
    this._super();
    unregisterTooltip($(this.element).find("[data-tooltip]"));
  },

  pickColorAtIndex(index) {
    return this._colorsPool[index] || this._colorsPool[0];
  },

  fetchReport() {
    this._super();

    let payload = this.buildPayload(["prev_period"]);

    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }

    return Ember.RSVP.Promise.all(
      this.get("dataSources").map(dataSource => {
        return ajax(dataSource, payload).then(response => {
          this.get("reports").pushObject(this.loadReport(response.report));
        });
      })
    );
  },

  loadReport(report, previousReport) {
    Report.fillMissingDates(report);

    if (report.data && report.data.length > 40) {
      report.data = collapseWeekly(report.data, report.average);
    }

    if (previousReport && previousReport.color.length) {
      report.color = previousReport.color;
    } else {
      const dataSourceNameIndex = this.get("dataSourceNames")
        .split(",")
        .indexOf(report.type);
      report.color = this.pickColorAtIndex(dataSourceNameIndex);
    }

    return Report.create(report);
  },

  renderReport() {
    this._super();

    Ember.run.schedule("afterRender", () => {
      const $chartCanvas = this.$(".chart-canvas");
      if (!$chartCanvas.length) return;
      const context = $chartCanvas[0].getContext("2d");

      const reportsForPeriod = this.get("reportsForPeriod");

      const labels = Ember.makeArray(
        reportsForPeriod.get("firstObject.data")
      ).map(d => d.x);

      const data = {
        labels,
        datasets: reportsForPeriod.map(report => {
          return {
            data: Ember.makeArray(report.data).map(d =>
              Math.round(parseFloat(d.y))
            ),
            backgroundColor: "rgba(200,220,240,0.3)",
            borderColor: report.color
          };
        })
      };

      if (this._chart) {
        this._chart.destroy();
        this._chart = null;
      }

      loadScript("/javascripts/Chart.min.js").then(() => {
        if (this._chart) {
          this._chart.destroy();
        }

        this._chart = new window.Chart(context, this._buildChartConfig(data));
      });
    });
  },

  _buildChartConfig(data) {
    return {
      type: "line",
      data,
      options: {
        tooltips: {
          callbacks: {
            title: context =>
              moment(context[0].xLabel, "YYYY-MM-DD").format("LL")
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
              ticks: { callback: label => number(label) }
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
  }
});
