export default Discourse.Route.extend({
  setupController(controller) {
    controller.fetchDashboard();
  }
});
