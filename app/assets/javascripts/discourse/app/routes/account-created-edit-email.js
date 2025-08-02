import Route from "@ember/routing/route";

export default class AccountCreatedEditEmail extends Route {
  setupController(controller) {
    const accountCreated =
      this.controllerFor("account-created").get("accountCreated");
    controller.set("accountCreated", accountCreated);
    controller.set("newEmail", accountCreated.email);
  }
}
