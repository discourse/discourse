import { service } from "discourse/lib/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";
import CurrentUserService from "discourse/services/current-user";
import ModalService from "discourse/services/modal";

export default class extends DiscourseRoute {
  @service(() => CurrentUserService) currentUser;
  @service(() => ModalService) modal;
  @service router;

  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
    } else {
      const { token } = this.paramsFor("associate-account");

      this.router
        .replaceWith("preferences.account", this.currentUser)
        .followRedirects()
        .then(async () => {
          try {
            const model = await ajax(
              `/associate/${encodeURIComponent(token)}.json`
            );
            this.modal.show(
              () =>
                import("discourse/components/modal/associate-account-confirm"),
              { model }
            );
          } catch (e) {
            popupAjaxError(e);
          }
        });
    }
  }
}
