import { ajax } from "discourse/lib/ajax";
import Report from "admin/models/report";
import AsyncReport from "admin/mixins/async-report";
import computed from "ember-addons/ember-computed-decorators";
import { number } from 'discourse/lib/formatter';

export default Ember.Component.extend(AsyncReport, {
  classNames: ["dashboard-table"],
  help: null,
  helpPage: null,

  @computed("report")
  values(report) {
    if (!report) return;
    return Ember.makeArray(report.data)
                .sort((a, b) => a.x >= b.x)
                .map(x => {
                  return [ x[0], number(x[1]), number(x[2]) ];
                });
  },

  @computed("report")
  labels(report) {
    if (!report) return;
    return Ember.makeArray(report.labels);
  },

  fetchReport() {
    this.set("isLoading", true);

    let payload = { data: { async: true } };

    if (this.get("startDate")) {
      payload.data.start_date = this.get("startDate").format("YYYY-MM-DD[T]HH:mm:ss.SSSZZ");
    }

    if (this.get("endDate")) {
      payload.data.end_date = this.get("endDate").format("YYYY-MM-DD[T]HH:mm:ss.SSSZZ");
    }

    ajax(this.get("dataSource"), payload)
      .then((response) => {
        this._setPropertiesFromReport(Report.create(response.report));
      }).finally(() => {
        if (!Ember.isEmpty(this.get("report.data"))) {
          this.set("isLoading", false);
        };
      });
  }
});
