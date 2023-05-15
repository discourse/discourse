import DiscourseRoute from "discourse/routes/discourse";
import { defaultHomepage } from "discourse/lib/utilities";
import { next } from "@ember/runloop";

export default class ForgotPasswordRoute extends DiscourseRoute {
  async beforeModel() {
    const { loginRequired } = this.controllerFor("application");

    const e = await this.replaceWith(
      loginRequired ? "login" : `discovery.${defaultHomepage()}`
    );

    next(() => e.send("showForgotPassword"));
  }
}
