import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  activate() {
    this.controllerFor("admin-dashboard-general").fetchDashboard();
  }
});
