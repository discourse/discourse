import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getWebauthnCredential } from "discourse/lib/webauthn";

export default Controller.extend({
  lockImageUrl: Discourse.getURL("/images/lock.svg"),

  @computed("model")
  secondFactorRequired(model) {
    return model.security_key_required || model.second_factor_required;
  },

  @computed("model")
  secondFactorMethod(model) {
    return model.security_key_required
      ? SECOND_FACTOR_METHODS.SECURITY_KEY
      : SECOND_FACTOR_METHODS.TOTP;
  },

  actions: {
    finishLogin() {
      let data = {};
      if (this.securityKeyCredential) {
        data = { security_key_credential: this.securityKeyCredential };
      } else {
        data = {
          second_factor_token: this.secondFactorToken,
          second_factor_method: this.secondFactorMethod
        };
      }
      ajax({
        url: `/session/email-login/${this.model.token}`,
        type: "POST",
        data: data
      })
        .then(result => {
          if (result.success) {
            DiscourseURL.redirectTo("/");
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
        credentialData => {
          this.set("securityKeyCredential", credentialData);
          this.send("finishLogin");
        },
        errorMessage => {
          this.set("model.error", errorMessage);
        }
      );
    }
  }
});
