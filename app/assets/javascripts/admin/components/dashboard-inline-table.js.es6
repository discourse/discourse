import { ajax } from "discourse/lib/ajax";
import Report from "admin/models/report";
import AsyncReport from "admin/mixins/async-report";

export default Ember.Component.extend(AsyncReport, {
  classNames: ["dashboard-table", "dashboard-inline-table", "fixed"],
  help: null,
  helpPage: null,
  title: null,
  loadingTitle: null,

  loadReport(report_json) {
    return Report.create(report_json);
  },

  fetchReport() {
    this._super();

    let payload = { data: { async: true, facets: ["total", "prev30Days"] } };

    if (this.get("startDate")) {
      payload.data.start_date = this.get("startDate").format("YYYY-MM-DD[T]HH:mm:ss.SSSZZ");
    }

    if (this.get("endDate")) {
      payload.data.end_date = this.get("endDate").format("YYYY-MM-DD[T]HH:mm:ss.SSSZZ");
    }

    if (this.get("limit")) {
      payload.data.limit = this.get("limit");
    }

    this.set("reports", Ember.Object.create());
    this.set("reportKeys", []);

    return Ember.RSVP.Promise.all(this.get("dataSources").map(dataSource => {
      return ajax(dataSource, payload)
        .then(response => {
          this.set(`reports.${response.report.report_key}`, this.loadReport(response.report));
          this.get("reportKeys").pushObject(response.report.report_key);
        });
    }));
  }
});
