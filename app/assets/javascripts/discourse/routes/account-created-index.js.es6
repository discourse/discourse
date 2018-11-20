export default Ember.Route.extend({
  setupController(controller) {
    controller.set(
      "accountCreated",
      this.controllerFor("account-created").get("accountCreated")
    );
  }
});
