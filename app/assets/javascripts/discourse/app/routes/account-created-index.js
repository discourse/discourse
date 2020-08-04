import Route from "@ember/routing/route";
export default Route.extend({
  setupController(controller) {
    controller.set(
      "accountCreated",
      this.controllerFor("account-created").get("accountCreated")
    );
  }
});
