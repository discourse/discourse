import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default class EmailLoginController extends Controller {
  @service router;

  secondFactorMethod;
  secondFactorToken;
  showTokenInput = false;

  lockImageUrl = getURL("/images/lock.svg");

  @computed("model")
  get secondFactorRequired() {
    return (
      this.model.security_key_required ||
      this.model.passkeys_enabled ||
      this.model.second_factor_required
    );
  }

  @computed(
    "model.security_key_required",
    "model.passkeys_enabled",
    "showTokenInput"
  )
  get showWebauthnForm() {
    return (
      (this.model.security_key_required || this.model.passkeys_enabled) &&
      !this.showTokenInput
    );
  }

  @computed("model.totp_enabled", "model.backup_codes_enabled")
  get otherTokenMethodsAllowed() {
    return this.model.totp_enabled || this.model.backup_codes_enabled;
  }

  @action
  async finishLogin() {
    let data = {
      second_factor_method: this.secondFactorMethod,
      timezone: moment.tz.guess(),
    };

    if (this.securityKeyCredential) {
      data.second_factor_token = this.securityKeyCredential;
    } else {
      data.second_factor_token = this.secondFactorToken;
    }

    try {
      const result = await ajax({
        url: `/session/email-login/${this.model.token}`,
        type: "POST",
        data,
      });

      if (!result.success) {
        this.set("model.error", result.error);
        return;
      }

      let destination = "/";

      const safeMode = new URL(
        this.router.currentURL,
        window.location.origin
      ).searchParams.get("safe_mode");

      if (safeMode) {
        const params = new URLSearchParams();
        params.set("safe_mode", safeMode);
        destination += `?${params.toString()}`;
      }

      DiscourseURL.redirectTo(destination);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  authenticateSecurityKey() {
    this.set("secondFactorMethod", SECOND_FACTOR_METHODS.SECURITY_KEY);
    getWebauthnCredential(
      this.model.challenge,
      this.model.allowed_credential_ids,
      (credentialData) => {
        this.set("securityKeyCredential", credentialData);
        this.send("finishLogin");
      },
      (errorMessage) => {
        this.set("model.error", errorMessage);
      }
    );
  }

  @action
  authenticatePasskey() {
    this.set("secondFactorMethod", SECOND_FACTOR_METHODS.PASSKEY);
    getWebauthnCredential(
      this.model.challenge,
      this.model.passkey_allowed_credential_ids,
      (credentialData) => {
        this.set("securityKeyCredential", credentialData);
        this.send("finishLogin");
      },
      (errorMessage) => {
        this.set("model.error", errorMessage);
      },
      { userVerification: "required" }
    );
  }
}
