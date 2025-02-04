import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ConfirmNewEmailController extends Controller {
  @service dialog;
  @service router;

  @tracked loading;

  @action
  async confirm() {
    this.loading = true;
    try {
      await ajax(`/u/confirm-new-email/${this.model.token}.json`, {
        type: "PUT",
      });
    } catch (error) {
      const nonce = error.jqXHR?.responseJSON?.second_factor_challenge_nonce;
      if (nonce) {
        this.router.transitionTo("second-factor-auth", {
          queryParams: { nonce },
        });
      } else {
        popupAjaxError(error);
      }
      return;
    } finally {
      this.loading = false;
    }

    await new Promise((resolve) =>
      this.dialog.dialog({
        message: i18n("user.change_email.confirm_success"),
        type: "alert",
        didConfirm: resolve,
      })
    );

    this.router.transitionTo("/my/preferences/account");
  }
}
