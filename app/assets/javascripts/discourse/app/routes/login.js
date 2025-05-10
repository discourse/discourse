import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import { defaultHomepage } from "discourse/lib/utilities";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  beforeModel(transition) {
    if (transition.from) {
      this.internalReferrer = this.router.urlFor(transition.from.name);
    }

    if (this.siteSettings.login_required) {
      if (
        this.login.isOnlyOneExternalLoginMethod &&
        this.siteSettings.auth_immediately &&
        !document.getElementById("data-authentication")?.dataset
          .authenticationData
      ) {
        this.login.singleExternalLogin();
      }
    } else if (this.login.isOnlyOneExternalLoginMethod) {
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
    controller.set("canSignUp", canSignUp);
    controller.set("flashType", "");
    controller.set("flash", "");

    if (
      this.internalReferrer ||
      DiscourseURL.isInternalTopic(document.referrer)
    ) {
      controller.set(
        "referrerTopicUrl",
        this.internalReferrer || document.referrer
      );
    }

    if (this.login.isOnlyOneExternalLoginMethod) {
      if (this.siteSettings.auth_immediately) {
        controller.set("isRedirectingToExternalAuth", true);
      } else {
        controller.set("singleExternalLogin", this.login.singleExternalLogin);
      }
    }
  }
}
