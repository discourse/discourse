import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminEmailTemplatesRoute extends Route {
  @service router;

  model() {
    return this.store.findAll("email-template");
  }

  setupController(controller, model) {
    controller.set("emailTemplates", model);
  }

  @action
  didTransition() {
    const editController = this.controllerFor("adminEmailTemplates.edit");

    if (!editController.emailTemplate) {
      this.router.transitionTo(
        "adminEmailTemplates.edit",
        this.controller.get("sortedTemplates.firstObject")
      );
    }
  }
}
