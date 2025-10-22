import Route from "@ember/routing/route";

export default class AccountCreatedResent extends Route {
  setupController(controller) {
    controller.set(
      "email",
      this.controllerFor("account-created").get("accountCreated.email")
    );
  }
}
