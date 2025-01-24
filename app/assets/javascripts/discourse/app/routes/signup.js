import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class SignupRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  autoRedirect = false;
  authComplete = false;
  singleLoginMethod = false;

  beforeModel(transition) {
    this.authComplete = transition.to.queryParams.authComplete || false;
    this.singleLoginMethod = this.login.isOnlyOneExternalLoginMethod;
    this.autoRedirect =
      !this.authComplete &&
      this.singleLoginMethod &&
      !this.siteSettings.login_required &&
      this.siteSettings.auth_immediately;

    if (this.autoRedirect) {
      this.login.singleExternalLogin({ signup: true });
    } else {
      this.showCreateAccount();
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (this.autoRedirect) {
      controller.set("isRedirectingToExternalAuth", true);
    }
  }

  @action
  async showCreateAccount() {
    const { canSignUp } = this.controllerFor("application");
    if (
      this.authComplete ||
      !this.siteSettings.auth_immediately ||
      (canSignUp &&
        this.siteSettings.full_page_login &&
        !this.singleLoginMethod)
    ) {
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
