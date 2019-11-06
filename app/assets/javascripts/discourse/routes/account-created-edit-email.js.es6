import Route from "@ember/routing/route";
export default Route.extend({
  setupController(controller) {
    const accountCreated = this.controllerFor("account-created").get(
      "accountCreated"
    );
    controller.set("accountCreated", accountCreated);
    controller.set("newEmail", accountCreated.email);
  }
});
