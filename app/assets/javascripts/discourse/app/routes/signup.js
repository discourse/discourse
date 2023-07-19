import DiscourseRoute from "discourse/routes/discourse";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";

export default class SignupRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    const { canSignUp } = this.controllerFor("application");

    if (this.siteSettings.login_required) {
      this.router.replaceWith("login").then((e) => {
        if (canSignUp) {
          next(() => e.send("showCreateAccount"));
        }
      });
    } else {
      this.router.replaceWith("discovery.latest").then((e) => {
        if (canSignUp) {
          next(() => e.send("showCreateAccount"));
        }
      });
    }
  }
}
