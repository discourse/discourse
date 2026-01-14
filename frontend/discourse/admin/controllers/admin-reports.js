import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminReportsController extends Controller {
  @service router;

  get hideTabs() {
    return ["adminReports.show"].includes(this.router.currentRouteName);
  }
}
