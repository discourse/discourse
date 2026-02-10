import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminReportsController extends Controller {
  @service router;

  get showHeader() {
    return this.router.currentRouteName === "adminReports.index";
  }
}
