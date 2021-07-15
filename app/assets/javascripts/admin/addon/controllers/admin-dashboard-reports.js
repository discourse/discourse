import Controller from "@ember/controller";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { get } from "@ember/object";

export default Controller.extend({
  filter: null,

  @discourseComputed(
    "model.[]",
    "filter",
    "siteSettings.dashboard_hidden_reports"
  )
  filterReports(reports, filter) {
    if (filter) {
      filter = filter.toLowerCase();
      reports = reports.filter((report) => {
        return (
          (get(report, "title") || "").toLowerCase().indexOf(filter) > -1 ||
          (get(report, "description") || "").toLowerCase().indexOf(filter) > -1
        );
      });
    }

    const hiddenReports = (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean);
    reports = reports.filter((report) => !hiddenReports.includes(report.type));

    return reports;
  },

  actions: {
    filterReports(filter) {
      discourseDebounce(this, this._performFiltering, filter, INPUT_DELAY);
    },
  },

  _performFiltering(filter) {
    this.set("filter", filter);
  },
});
