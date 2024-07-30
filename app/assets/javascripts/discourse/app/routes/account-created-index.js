import Route from "@ember/routing/route";

export default class AccountCreatedIndex extends Route {
  setupController(controller) {
    controller.set(
      "accountCreated",
      this.controllerFor("account-created").get("accountCreated")
    );
  }
}
