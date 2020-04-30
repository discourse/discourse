import discourseComputed from "discourse-common/utils/decorators";
import { debounce } from "@ember/runloop";
import Controller from "@ember/controller";
import { INPUT_DELAY } from "discourse-common/config/environment";

const { get } = Ember;

export default Controller.extend({
  filter: null,

  @discourseComputed(
    "model.[]",
    "filter",
    "siteSettings.dashboard_visible_reports"
  )
  filterReports(reports, filter) {
    if (filter) {
      filter = filter.toLowerCase();
      return reports.filter(report => {
        return (
          (get(report, "title") || "").toLowerCase().indexOf(filter) > -1 ||
          (get(report, "description") || "").toLowerCase().indexOf(filter) > -1
        );
      });
    }

    const visibleReports = (this.siteSettings.dashboard_visible_reports || "")
      .split("|")
      .filter(Boolean);
    reports = reports.filter(report => {
      return visibleReports.includes(report.type);
    });

    return reports;
  },

  actions: {
    filterReports(filter) {
      debounce(this, this._performFiltering, filter, INPUT_DELAY);
    }
  },

  _performFiltering(filter) {
    this.set("filter", filter);
  }
});
