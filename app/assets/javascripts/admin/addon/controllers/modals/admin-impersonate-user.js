import Controller from "@ember/controller";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { schedule } from "@ember/runloop";

export default Controller.extend(ModalFunctionality, {
  username: alias("model.username"),
  errorMessage: null,
  showDescription: true,
  showSecurityKey: false,
  showSecondFactor: false,
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,

  onShow() {
    this.setProperties({
      showDescription: true,
      showSecurityKey: false,
      showSecondFactor: false,
      secondFactorRequired: false,
    });
  },

  @discourseComputed("showSecondFactor", "showSecurityKey")
  descriptionClass(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey ? "hidden" : "";
  },

  @discourseComputed("showSecondFactor", "showSecurityKey")
  secondFactorClass(showSecondFactor, showSecurityKey) {
    return showSecondFactor || showSecurityKey ? "" : "hidden";
  },

  @action
  impersonate() {
    ajax("/admin/impersonate", {
      type: "POST",
      data: {
        username_or_email: this.username,
        second_factor_token:
          this.securityKeyCredential || this.secondFactorToken,
        second_factor_method: this.secondFactorMethod,
        timezone: moment.tz.guess(),
      },
    }).then(
      (result) => {
        // Successful login
        if (result && result.error) {
          if (
            (result.security_key_enabled || result.totp_enabled) &&
            !this.secondFactorRequired
          ) {
            this.setProperties({
              otherMethodAllowed: result.multiple_second_factor_methods,
              secondFactorRequired: true,
              showLoginButtons: false,
              backupEnabled: result.backup_enabled,
              showSecondFactor: result.totp_enabled,
              showSecurityKey: result.security_key_enabled,
              secondFactorMethod: result.security_key_enabled
                ? SECOND_FACTOR_METHODS.SECURITY_KEY
                : SECOND_FACTOR_METHODS.TOTP,
              securityKeyChallenge: result.challenge,
              securityKeyAllowedCredentialIds: result.allowed_credential_ids,
            });

            // only need to focus the 2FA input for TOTP
            if (!this.showSecurityKey) {
              schedule("afterRender", () =>
                document
                  .getElementById("second-factor")
                  .querySelector("input")
                  .focus()
              );
            }

            return;
          } else {
            this.flash(result.error, "error");
          }
        } else {
          DiscourseURL.redirectTo("/");
        }
      },
      (e) => {
        if (e.status === 404) {
          bootbox.alert(I18n.t("admin.impersonate.not_found"));
        } else {
          bootbox.alert(I18n.t("admin.impersonate.invalid"));
        }
      }
    );
  },

  @action
  authenticateSecurityKey() {
    getWebauthnCredential(
      this.securityKeyChallenge,
      this.securityKeyAllowedCredentialIds,
      (credentialData) => {
        this.set("securityKeyCredential", credentialData);
        this.send("login");
      },
      (errorMessage) => {
        this.flash(errorMessage, "error");
      }
    );
  },

  @action
  close() {
    this.send("closeModal");
  },
});
