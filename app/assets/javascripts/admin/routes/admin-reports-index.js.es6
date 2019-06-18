export default Discourse.Route.extend({
  beforeModel() {
    this.transitionTo("admin.dashboardReports");
  }
});
