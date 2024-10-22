import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class SignupRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    this.showCreateAccount();
  }

  @action
  async showCreateAccount() {
    const { canSignUp } = this.controllerFor("application");
    if (canSignUp && this.siteSettings.experimental_full_page_login) {
      return;
    }
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
