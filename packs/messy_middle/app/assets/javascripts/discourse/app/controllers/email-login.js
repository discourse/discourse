import Controller from "@ember/controller";
import DiscourseURL from "discourse/lib/url";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default Controller.extend({
  router: service(),

  lockImageUrl: getURL("/images/lock.svg"),

  @discourseComputed("model")
  secondFactorRequired(model) {
    return model.security_key_required || model.second_factor_required;
  },

  @discourseComputed("model")
  secondFactorMethod(model) {
    return model.security_key_required
      ? SECOND_FACTOR_METHODS.SECURITY_KEY
      : SECOND_FACTOR_METHODS.TOTP;
  },

  actions: {
    finishLogin() {
      let data = {
        second_factor_method: this.secondFactorMethod,
        timezone: moment.tz.guess(),
      };
      if (this.securityKeyCredential) {
        data.second_factor_token = this.securityKeyCredential;
      } else {
        data.second_factor_token = this.secondFactorToken;
      }

      ajax({
        url: `/session/email-login/${this.model.token}`,
        type: "POST",
        data,
      })
        .then((result) => {
          if (result.success) {
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
          } else {
            this.set("model.error", result.error);
          }
        })
        .catch(popupAjaxError);
    },
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
    },
  },
});
