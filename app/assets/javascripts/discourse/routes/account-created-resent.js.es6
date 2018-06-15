export default Ember.Route.extend({
  setupController(controller) {
    controller.set(
      "email",
      this.controllerFor("account-created").get("accountCreated.email")
    );
  }
});
