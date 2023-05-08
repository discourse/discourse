import DiscourseRoute from "discourse/routes/discourse";
import { defaultHomepage } from "discourse/lib/utilities";
import { next } from "@ember/runloop";
import StaticPage from "discourse/models/static-page";

export default class LoginRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.siteSettings.login_required) {
      this.replaceWith(`/${defaultHomepage()}`).then((e) => {
        next(() => e.send("showLogin"));
      });
    }
  }

  model() {
    return StaticPage.find("login");
  }
}
