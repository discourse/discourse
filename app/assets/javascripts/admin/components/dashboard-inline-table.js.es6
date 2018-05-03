import { ajax } from 'discourse/lib/ajax';
import Report from "admin/models/report";
import AsyncReport from "admin/mixins/async-report";

export default Ember.Component.extend(AsyncReport, {
  classNames: ["dashboard-table", "dashboard-inline-table", "fixed"],
  isLoading: true,
  help: null,
  helpPage: null,

  fetchReport() {
    this.set("isLoading", true);

    ajax(this.get("dataSource"))
      .then((response) => {
        this._setPropertiesFromReport(Report.create(response.report));
      }).finally(() => {
        if (!Ember.isEmpty(this.get("report.data"))) {
          this.set("isLoading", false);
        };
      });
  }
});
