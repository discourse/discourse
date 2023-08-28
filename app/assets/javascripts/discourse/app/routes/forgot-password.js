import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import { next } from "@ember/runloop";
import ForgotPassword from "discourse/components/modal/forgot-password";

export default class ForgotPasswordRoute extends DiscourseRoute {
  @service modal;
  @service router;

  async beforeModel() {
    const { loginRequired } = this.controllerFor("application");

    await this.router.replaceWith(
      loginRequired ? "login" : `discovery.${defaultHomepage()}`
    );
    next(() => this.modal.show(ForgotPassword));
  }
}
