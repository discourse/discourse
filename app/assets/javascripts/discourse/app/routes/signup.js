import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class SignupRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  authComplete = false;

  beforeModel(transition) {
    this.authComplete = transition.to.queryParams.authComplete || false;

    if (this.login.isOnlyOneExternalLoginMethod && !this.authComplete) {
      this.login.singleExternalLogin();
    } else {
      this.showCreateAccount();
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (this.login.isOnlyOneExternalLoginMethod && !this.authComplete) {
      controller.set("isRedirecting", true);
    }
  }

  @action
  async showCreateAccount() {
    const { canSignUp } = this.controllerFor("application");
    if (canSignUp && this.siteSettings.full_page_login) {
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
