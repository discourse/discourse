import Route from "@ember/routing/route";
export default Route.extend({
  setupController(controller) {
    controller.set(
      "email",
      this.controllerFor("account-created").get("accountCreated.email")
    );
  }
});
