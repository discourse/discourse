import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import { next } from "@ember/runloop";
import StaticPage from "discourse/models/static-page";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;

  controllerName = "login-page";

  beforeModel() {
    if (!this.siteSettings.login_required) {
      this.replaceWith(`/${defaultHomepage()}`).then((e) => {
        next(() => e.send("showLogin"));
      });
    }
  }

  async model() {
    return {
      page: await StaticPage.find("login"),
      canSignUp: this.controllerFor("application").canSignUp,
    };
  }
}
