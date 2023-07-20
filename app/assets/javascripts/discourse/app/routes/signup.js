import DiscourseRoute from "discourse/routes/discourse";
import { next } from "@ember/runloop";

export default class SignupRoute extends DiscourseRoute {
  beforeModel() {
    const { canSignUp } = this.controllerFor("application");

    if (this.siteSettings.login_required) {
      this.replaceWith("login").then((e) => {
        if (canSignUp) {
          next(() => e.send("showCreateAccount"));
        }
      });
    } else {
      this.replaceWith("discovery.latest").then((e) => {
        if (canSignUp) {
          next(() => e.send("showCreateAccount"));
        }
      });
    }
  }
}
