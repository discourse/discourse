import { service } from "@ember/service";
import AssociateAccountConfirm from "discourse/components/modal/associate-account-confirm";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  @service currentUser;
  @service modal;
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
            this.modal.show(AssociateAccountConfirm, { model });
          } catch (e) {
            popupAjaxError(e);
          }
        });
    }
  }
}
