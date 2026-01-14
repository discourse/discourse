import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class UserBillingRoute extends Route {
  @service router;

  templateName = "user/billing";

  setupController(controller, model) {
    if (this.currentUser.id !== this.modelFor("user").id) {
      this.router.replaceWith("userActivity");
    } else {
      controller.setProperties({ model });
    }
  }
}
