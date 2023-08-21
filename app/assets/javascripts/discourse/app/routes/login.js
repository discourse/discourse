import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import { next } from "@ember/runloop";
import StaticPage from "discourse/models/static-page";

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
