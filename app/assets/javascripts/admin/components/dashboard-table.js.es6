import { ajax } from "discourse/lib/ajax";
import Report from "admin/models/report";
import AsyncReport from "admin/mixins/async-report";
import computed from "ember-addons/ember-computed-decorators";
import { number } from 'discourse/lib/formatter';

export default Ember.Component.extend(AsyncReport, {
  classNames: ["dashboard-table"],
  classNameBindings : ["isDisabled"],
  help: null,
  helpPage: null,
  isDisabled: Ember.computed.not("siteSettings.log_search_queries"),
  disabledLabel: "admin.dashboard.reports.disabled",

  @computed("report")
  values(report) {
    if (!report) return;
    return Ember.makeArray(report.data)
                .map(x => {
                  return [ x[0], number(x[1]), x[2] ];
                });
  },

  @computed("report")
  labels(report) {
    if (!report) return;
    return Ember.makeArray(report.labels);
  },

  loadReport(report_json) {
    this._setPropertiesFromReport(Report.create(report_json));
  },

  fetchReport() {
    if (this.get("isDisabled")) return;

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
        this.set('reportKey', response.report.report_key);
        this.loadReport(response.report);
      }).finally(() => {
        if (!Ember.isEmpty(this.get("report.data"))) {
          this.set("isLoading", false);
        };
      });
  }
});
