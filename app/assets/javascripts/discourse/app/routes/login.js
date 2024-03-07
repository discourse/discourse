import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;

  // `login-page` because `login` controller is the one for
  // the login modal
  controllerName = "login-page";

  beforeModel() {
    if (!this.siteSettings.login_required) {
      this.router
        .replaceWith(`/${defaultHomepage()}`)
        .followRedirects()
        .then((e) => next(() => e.send("showLogin")));
    }
  }

  model() {
    return StaticPage.find("login");
  }
}
