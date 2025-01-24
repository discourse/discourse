import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  beforeModel() {
    if (this.siteSettings.login_required) {
      return;
    }

    if (this.login.isOnlyOneExternalLoginMethod) {
      this.login.singleExternalLogin();
    } else if (
      !this.siteSettings.full_page_login ||
      this.siteSettings.enable_discourse_connect
    ) {
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

    if (this.login.isOnlyOneExternalLoginMethod) {
      if (this.siteSettings.login_required) {
        controller.set("autoRedirect", true);
        controller.set("singleExternalLogin", this.login.singleExternalLogin);
      } else {
        controller.set("isRedirectingToExternalAuth", true);
      }
    }

    if (this.siteSettings.login_required) {
      controller.set("showLogin", false);
    }
  }
}
