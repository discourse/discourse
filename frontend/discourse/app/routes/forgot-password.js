import { next } from "@ember/runloop";
import { service } from "@ember/service";
import ForgotPassword from "discourse/components/modal/forgot-password";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import DiscourseRoute from "discourse/routes/discourse";

export default class ForgotPasswordRoute extends DiscourseRoute {
  @service modal;
  @service router;

  async beforeModel() {
    const { loginRequired } = this.controllerFor("application");

    await this.router.replaceWith(
      loginRequired ? "login" : homepageNavigationDestination()
    );
    next(() => this.modal.show(ForgotPassword));
  }
}
