import { next } from "@ember/runloop";
import { service } from "@ember/service";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { defaultHomepage } from "discourse/lib/utilities";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;

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

      window.addEventListener("unload", (event) => {
        event.preventDefault();
        removeCookie("destination_url");
      });
    }

    if (
      !this.siteSettings.login_required &&
      (!this.siteSettings.full_page_login ||
        this.siteSettings.enable_discourse_connect)
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

    if (this.siteSettings.login_required) {
      controller.set("showLogin", false);
    }
  }
}
