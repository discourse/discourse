import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { wavingHandURL } from "discourse/lib/waving-hand-url";
import I18n from "discourse-i18n";

export default class ActivateAccountController extends Controller {
  @service siteSettings;
  @service router;

  @tracked accountActivated = false;
  @tracked buttonDisabled = false;
  @tracked needsApproval = false;
  @tracked errorMessage = null;

  get siteName() {
    return this.siteSettings.title;
  }

  get wavingHandURL() {
    return wavingHandURL();
  }

  get translatedButtonLabel() {
    return I18n.t("user.activate_account.continue_button", {
      site_name: this.siteName,
    });
  }

  @action
  async activate() {
    this.buttonDisabled = true;

    let hp;
    try {
      const response = await fetch("/session/hp", {
        headers: {
          Accept: "application/json",
        },
      });
      hp = await response.json();
    } catch (error) {
      this.buttonDisabled = false;
      popupAjaxError(error);
      return;
    }

    try {
      const response = await ajax(
        `/u/activate-account/${this.model.token}.json`,
        {
          type: "PUT",
          data: {
            password_confirmation: hp.value,
            challenge: hp.challenge.split("").reverse().join(""),
          },
        }
      );
      if (response.success) {
        this.accountActivated = true;
        if (response.redirect_to) {
          window.location.href = response.redirect_to;
        } else {
          this.needsApproval = response.needs_approval;
          if (!response.needs_approval) {
            setTimeout(() => {
              window.location.href = "/";
            }, 2000);
          }
        }
      }
    } catch (error) {
      this.errorMessage = I18n.t("user.activate_account.already_done");
    }
  }
}
