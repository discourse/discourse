import Route from "@ember/routing/route";
import { action } from "@ember/object";

export default class AdminCustomizeEmailTemplatesRoute extends Route {
  model() {
    return this.store.findAll("email-template");
  }

  setupController(controller, model) {
    controller.set("emailTemplates", model);
  }

  @action
  didTransition() {
    const editController = this.controllerFor(
      "adminCustomizeEmailTemplates.edit"
    );

    if (!editController.emailTemplate) {
      this.transitionTo(
        "adminCustomizeEmailTemplates.edit",
        this.controller.get("sortedTemplates.firstObject")
      );
    }
  }
}
