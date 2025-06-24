import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class SignupRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  authComplete = false;

  beforeModel({ from }) {
    if (from) {
      this.internalReferrer = this.router.urlFor(from.name);
    }

    this.authComplete = document.getElementById(
      "data-authentication"
    )?.dataset.authenticationData;

    if (this.login.isOnlyOneExternalLoginMethod && !this.authComplete) {
      this.login.singleExternalLogin({ signup: true });
    } else {
      this.showCreateAccount();
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (
      this.internalReferrer ||
      DiscourseURL.isInternalTopic(document.referrer)
    ) {
      cookie("destination_url", this.internalReferrer || document.referrer);
    }

    if (this.login.isOnlyOneExternalLoginMethod && !this.authComplete) {
      controller.set("isRedirectingToExternalAuth", true);
    }
  }

  @action
  async showCreateAccount() {
    const { canSignUp } = this.controllerFor("application");
    if (!canSignUp) {
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
}
