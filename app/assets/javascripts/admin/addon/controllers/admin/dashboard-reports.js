import Controller from "@ember/controller";
import { action, get } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class AdminDashboardReportsController extends Controller {
  filter = null;

  @discourseComputed(
    "model.[]",
    "filter",
    "siteSettings.dashboard_hidden_reports"
  )
  filteredReports(reports, filter) {
    if (filter) {
      filter = filter.toLowerCase();
      reports = reports.filter((report) => {
        return (
          (get(report, "title") || "").toLowerCase().includes(filter) ||
          (get(report, "description") || "").toLowerCase().includes(filter)
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
