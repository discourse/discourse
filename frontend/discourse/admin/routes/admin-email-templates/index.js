import Route from "@ember/routing/route";

export default class AdminEmailTemplatesIndexRoute extends Route {
  setupController(controller, model, transition) {
    const parentController = this.controllerFor("adminEmailTemplates");
    controller.set("emailTemplates", parentController.get("model"));

    // `overridden` is deliberately not a registered query param; seeding here
    // (rather than in the controller) makes each visit reflect its own URL
    controller.set(
      "showOverridenOnly",
      transition.to.queryParams.overridden === "true"
    );
  }
}
