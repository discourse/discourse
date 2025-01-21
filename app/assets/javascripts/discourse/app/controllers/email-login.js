import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { getWebauthnCredential } from "discourse/lib/webauthn";

export default class EmailLoginController extends Controller {
  @service router;

  secondFactorMethod;
  secondFactorToken;

  lockImageUrl = getURL("/images/lock.svg");

  @discourseComputed("model")
  secondFactorRequired(model) {
    return model.security_key_required || model.second_factor_required;
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
}
