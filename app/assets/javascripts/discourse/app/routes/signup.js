import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class SignupRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  authComplete = false;

  beforeModel() {
    this.authComplete = document.getElementById(
      "data-authentication"
    )?.dataset.authenticationData;

    if (this.login.isOnlyOneExternalLoginMethod && !this.authComplete) {
      this.login.singleExternalLogin({ signup: true });
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (this.login.isOnlyOneExternalLoginMethod && !this.authComplete) {
      controller.set("isRedirectingToExternalAuth", true);
    }
  }
}
