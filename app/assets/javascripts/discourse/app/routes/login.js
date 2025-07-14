import { next } from "@ember/runloop";
import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import DiscourseURL from "discourse/lib/url";
import { defaultHomepage } from "discourse/lib/utilities";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  beforeModel({ from }) {
    if (document.getElementById("data-authentication")) {
      return;
    }

    if (from) {
      this.internalReferrer = this.router.urlFor(from.name);
    }

    if (
      this.login.isOnlyOneExternalLoginMethod &&
      this.siteSettings.auth_immediately
    ) {
      this.login.singleExternalLogin();
    } else if (this.siteSettings.enable_discourse_connect) {
      this.router
        .replaceWith(`/${defaultHomepage()}`)
        .followRedirects()
        .then((e) => next(() => e.send("showLogin")));
    }
  }

  model() {
    if (this.siteSettings.login_required) {
      return StaticPage.find("login");
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    const { canSignUp } = this.controllerFor("application");
    controller.setProperties({ canSignUp, flashType: "", flash: "" });

    if (
      this.internalReferrer ||
      DiscourseURL.isInternalTopic(document.referrer)
    ) {
      cookie("destination_url", this.internalReferrer || document.referrer);
    }

    if (this.login.isOnlyOneExternalLoginMethod) {
      controller.set("singleExternalLogin", this.login.singleExternalLogin);
      if (
        this.siteSettings.auth_immediately &&
        !document.getElementById("data-authentication")
      ) {
        controller.set("isRedirectingToExternalAuth", true);
      }
    }
  }
}
