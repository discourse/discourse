import Route from "@ember/routing/route";

export default class AdminEmailTemplatesIndexRoute extends Route {
  setupController(controller) {
    const parentController = this.controllerFor("adminEmailTemplates");
    controller.set("emailTemplates", parentController.get("model"));
  }
}
