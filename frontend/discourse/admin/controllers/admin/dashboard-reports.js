import Controller from "@ember/controller";
import { action, computed, get } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class AdminDashboardReportsController extends Controller {
  filter = null;

  @computed("model.[]", "filter", "siteSettings.dashboard_hidden_reports")
  get filteredReports() {
    let reports = this.model;
    const filter = this.filter;

    if (filter) {
      const lowerCaseFilter = filter.toLowerCase();
      reports = reports.filter((report) => {
        return (
          (get(report, "title") || "")
            .toLowerCase()
            .includes(lowerCaseFilter) ||
          (get(report, "description") || "")
            .toLowerCase()
            .includes(lowerCaseFilter)
        );
      });
    }

    const hiddenReports = (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean);
    reports = reports.filter((report) => !hiddenReports.includes(report.type));

    return reports;
  }

  @action
  filterReports(filter) {
    discourseDebounce(this, this._performFiltering, filter, INPUT_DELAY);
  }

  _performFiltering(filter) {
    this.set("filter", filter);
  }
}
