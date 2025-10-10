import Route from "@ember/routing/route";
import { scrollTop } from "discourse/lib/scroll-top";

export default class AdminEmailTemplatesEditRoute extends Route {
  model(params) {
    const all = this.modelFor("adminEmailTemplates");
    return all.find((value) => value.id === params.id);
  }

  setupController(controller, emailTemplate) {
    controller.setProperties({ emailTemplate, saved: false });
    scrollTop();
  }

  deactivate() {
    this.controller.set("emailTemplate", null);
  }
}
