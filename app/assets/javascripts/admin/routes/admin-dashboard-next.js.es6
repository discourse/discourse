import loadScript from "discourse/lib/load-script";

export default Discourse.Route.extend({
  activate() {
    loadScript("/javascripts/Chart.min.js").then(() => {
      this.controllerFor('admin-dashboard-next').fetchDashboard();
    });
  }
});
