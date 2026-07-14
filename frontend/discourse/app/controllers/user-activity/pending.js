import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";

export default class UserActivityPendingController extends Controller {
  @service dialog;
  @controller user;

  get canDeletePending() {
    return this.user.viewingSelf;
  }

  @action
  deletePending(pending) {
    return this.dialog.deleteConfirm({
      message: i18n("review.delete_confirm"),
      didConfirm: async () => {
        try {
          await ajax(`/review/${pending.id}`, { type: "DELETE" });
          removeValueFromArray(this.model.content, pending);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }
}
