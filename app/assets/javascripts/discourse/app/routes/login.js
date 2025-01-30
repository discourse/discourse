import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRoute extends DiscourseRoute {
  @service siteSettings;
  @service router;

  beforeModel() {
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

  setupController(controller) {
    super.setupController(...arguments);

    const { canSignUp } = this.controllerFor("application");
    controller.set("canSignUp", canSignUp);
    controller.set("flashType", "");
    controller.set("flash", "");
  }
}
