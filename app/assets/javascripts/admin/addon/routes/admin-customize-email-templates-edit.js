import Route from "@ember/routing/route";
import { scrollTop } from "discourse/mixins/scroll-top";

export default class AdminCustomizeEmailTemplatesEditRoute extends Route {
  model(params) {
    const all = this.modelFor("adminCustomizeEmailTemplates");
    return all.findBy("id", params.id);
  }

  setupController(controller, emailTemplate) {
    controller.setProperties({ emailTemplate, saved: false });
    scrollTop();
  }

  deactivate() {
    this.controller.set("emailTemplate", null);
  }
}
