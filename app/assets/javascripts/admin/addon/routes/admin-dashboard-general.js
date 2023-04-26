import DiscourseRoute from "discourse/routes/discourse";

export default class AdminDashboardGeneralRoute extends DiscourseRoute {
  activate() {
    this.controllerFor("admin-dashboard-general").fetchDashboard();
  }
}
