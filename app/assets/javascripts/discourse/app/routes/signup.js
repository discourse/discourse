import DiscourseRoute from "discourse/routes/discourse";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class SignupRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    this.showCreateAccount();
  }

  @action
  async showCreateAccount() {
    const { canSignUp } = this.controllerFor("application");
    const route = await this.router
      .replaceWith(
        this.siteSettings.login_required ? "login" : "discovery.latest"
      )
      .followRedirects();
    if (canSignUp) {
      next(() => route.send("showCreateAccount"));
    }
  }
}
