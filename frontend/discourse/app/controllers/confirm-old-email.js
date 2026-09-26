import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import CurrentUserService from "discourse/services/current-user";
import DialogService from "discourse/dialog-holder/services/dialog";

export default class ConfirmOldEmailController extends Controller {
  @service(() => CurrentUserService) currentUser;
  @service(() => DialogService) dialog;
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

    this.router.transitionTo(
      `/u/${this.currentUser.username_lower}/preferences/account`
    );
  }
}
