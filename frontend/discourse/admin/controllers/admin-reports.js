import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminReportsController extends Controller {
  @service router;
  @service siteSettings;

  get reportingImprovements() {
    return this.siteSettings.reporting_improvements;
  }

  get showHeader() {
    return this.router.currentRouteName === "adminReports.index";
  }

  get hideTabs() {
    return ["adminReports.show"].includes(this.router.currentRouteName);
  }
}
