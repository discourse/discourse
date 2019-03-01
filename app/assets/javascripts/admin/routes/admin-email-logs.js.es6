export default Discourse.Route.extend({
  setupController(controller) {
    controller.setProperties({
      loading: true,
      filter: { status: this.get("status") }
    });
  }
});
