import { ajax } from 'discourse/lib/ajax';
import Report from "admin/models/report";
import AsyncReport from "admin/mixins/async-report";

export default Ember.Component.extend(AsyncReport, {
  classNames: ["dashboard-table", "dashboard-inline-table", "fixed"],
  isLoading: true,
  help: null,
  helpPage: null,

  loadReport(report_json) {
    this._setPropertiesFromReport(Report.create(report_json));
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

    if (this.get("limit")) {
      payload.data.limit = this.get("limit");
    }

    ajax(this.get("dataSource"), payload)
      .then((response) => {
        this.set('reportKey', response.report.report_key);
        this.loadReport(response.report);
      }).finally(() => {
        if (!Ember.isEmpty(this.get("report.data"))) {
          this.set("isLoading", false);
        };
      });
  }
});
