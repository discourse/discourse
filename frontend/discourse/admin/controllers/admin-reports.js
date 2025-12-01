import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class AdminReportsController extends Controller {
  @service router;

  @tracked reports = null;

  constructor() {
    super(...arguments);
    this.loadReports();
  }

  async loadReports() {
    try {
      const response = await ajax("/admin/reports");
      this.reports = response.reports;
    } catch {
      // Fail silently, breadcrumb will just not show report title
    }
  }

  get hideTabs() {
    return ["adminReports.show"].includes(this.router.currentRouteName);
  }

  get isShowRoute() {
    return this.router.currentRouteName === "adminReports.show";
  }

  get currentReportType() {
    return this.router.currentRoute?.params?.type;
  }

  get currentReport() {
    if (!this.isShowRoute || !this.currentReportType || !this.reports) {
      return null;
    }

    return this.reports.find(
      (report) => report.type === this.currentReportType
    );
  }

  get currentReportTitle() {
    return this.currentReport?.title;
  }
}
