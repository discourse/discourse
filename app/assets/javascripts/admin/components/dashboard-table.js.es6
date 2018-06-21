import { ajax } from "discourse/lib/ajax";
import AsyncReport from "admin/mixins/async-report";

export default Ember.Component.extend(AsyncReport, {
  classNames: ["dashboard-table"],

  fetchReport() {
    this._super();

    let payload = this.buildPayload(["total", "prev30Days"]);

    return Ember.RSVP.Promise.all(
      this.get("dataSources").map(dataSource => {
        return ajax(dataSource, payload).then(response => {
          this.get("reports").pushObject(this.loadReport(response.report));
        });
      })
    );
  }
});
