import DiscourseRoute from "discourse/routes/discourse";

export default class AdminDashboardGeneralRoute extends DiscourseRoute {
  activate() {
    if (this.controllerFor("admin.dashboard").showRedesign) {
      return;
    }

    this.controllerFor("admin.dashboard.general").fetchDashboard();
  }
}
