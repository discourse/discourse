import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ConfirmOldEmailController extends Controller {
  @service dialog;
  @service router;

  @tracked loading;

  @action
  async confirm() {
    this.loading = true;
    try {
      await ajax(`/u/confirm-old-email/${this.model.token}.json`, {
        type: "PUT",
      });
    } catch (error) {
      popupAjaxError(error);
      return;
    } finally {
      this.loading = false;
    }

    await new Promise((resolve) =>
      this.dialog.dialog({
        message: i18n("user.change_email.authorizing_old.confirm_success"),
        type: "alert",
        didConfirm: resolve,
      })
    );

    this.router.transitionTo("/my/preferences/account");
  }
}
