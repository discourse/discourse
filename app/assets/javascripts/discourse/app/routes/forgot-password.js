import DiscourseRoute from "discourse/routes/discourse";
import { defaultHomepage } from "discourse/lib/utilities";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";

export default class ForgotPasswordRoute extends DiscourseRoute {
  @service router;

  async beforeModel() {
    const { loginRequired } = this.controllerFor("application");

    const e = await this.router.replaceWith(
      loginRequired ? "login" : `discovery.${defaultHomepage()}`
    );

    next(() => e.send("showForgotPassword"));
  }
}
