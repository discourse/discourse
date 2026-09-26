import { next } from "@ember/runloop";
import { service } from "discourse/lib/service";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import DiscourseRoute from "discourse/routes/discourse";
import ModalService from "discourse/services/modal";

export default class ForgotPasswordRoute extends DiscourseRoute {
  @service(() => ModalService) modal;
  @service router;

  async beforeModel() {
    const { loginRequired } = this.controllerFor("application");

    await this.router.replaceWith(
      loginRequired ? "login" : homepageNavigationDestination()
    );
    next(() =>
      this.modal.show(
        () => import("discourse/components/modal/forgot-password")
      )
    );
  }
}
