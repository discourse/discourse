import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { defaultHomepage } from "discourse/lib/utilities";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;
  @service login;

  queryParams = {
    redirect: { refreshModel: true },
  };

  beforeModel(transition) {
    const redirect = transition.to.queryParams.redirect;

    if (redirect) {
      const normalizedRedirect = redirect.startsWith("/")
        ? redirect
        : `/${redirect}`;
      const rootUrl = this.router.rootURL;
      const destinationUrl =
        rootUrl === "/"
          ? normalizedRedirect
          : `${rootUrl.replace(/\/$/, "")}${normalizedRedirect}`;

      cookie("destination_url", destinationUrl);
      this.controllerFor("application").set("hasRedirectParam", true);
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
    } else if (
      this.login.isOnlyOneExternalLoginMethod &&
      this.siteSettings.full_page_login
    ) {
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

  @action
  willTransition() {
    const { hasRedirectParam } = this.controllerFor("application");

    if (hasRedirectParam) {
      removeCookie("destination_url");
      this.controller.set("redirect", null);
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

    if (this.siteSettings.login_required) {
      controller.set("showLogin", false);
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
