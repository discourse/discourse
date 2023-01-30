import DiscourseURL, { userPath } from "discourse/lib/url";
import { action } from "@ember/object";
import { alias, or, readOnly } from "@ember/object/computed";
import Controller from "@ember/controller";
import I18n from "I18n";
import PasswordValidation from "discourse/mixins/password-validation";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { modKeysPressed } from "discourse/lib/utilities";

export default Controller.extend(PasswordValidation, {
  isDeveloper: alias("model.is_developer"),
  admin: alias("model.admin"),
  secondFactorRequired: alias("model.second_factor_required"),
  securityKeyRequired: alias("model.security_key_required"),
  backupEnabled: alias("model.backup_enabled"),
  securityKeyOrSecondFactorRequired: or(
    "model.second_factor_required",
    "model.security_key_required"
  ),
  otherMethodAllowed: readOnly("model.multiple_second_factor_methods"),
  @discourseComputed("model.security_key_required")
  secondFactorMethod(security_key_required) {
    return security_key_required
      ? SECOND_FACTOR_METHODS.SECURITY_KEY
      : SECOND_FACTOR_METHODS.TOTP;
  },
  passwordRequired: true,
  errorMessage: null,
  successMessage: null,
  requiresApproval: false,
  redirected: false,
  maskPassword: true,

  @discourseComputed()
  continueButtonText() {
    return I18n.t("password_reset.continue", {
      site_name: this.siteSettings.title,
    });
  },

  @discourseComputed("redirectTo")
  redirectHref(redirectTo) {
    return getURL(redirectTo || "/");
  },

  lockImageUrl: getURL("/images/lock.svg"),

  @action
  done(event) {
    if (event && modKeysPressed(event).length > 0) {
      return false;
    }
    event?.preventDefault();
    this.set("redirected", true);
    DiscourseURL.redirectTo(this.redirectTo || "/");
  },

  @action
  togglePasswordMask() {
    this.toggleProperty("maskPassword");
  },

  actions: {
    submit() {
      ajax({
        url: userPath(`password-reset/${this.get("model.token")}.json`),
        type: "PUT",
        data: {
          password: this.accountPassword,
          second_factor_token:
            this.securityKeyCredential || this.secondFactorToken,
          second_factor_method: this.secondFactorMethod,
          timezone: moment.tz.guess(),
        },
      })
        .then((result) => {
          if (result.success) {
            this.set("successMessage", result.message);
            this.set("redirectTo", result.redirect_to);
            if (result.requires_approval) {
              this.set("requiresApproval", true);
            } else {
              this.set("redirected", true);
              DiscourseURL.redirectTo(result.redirect_to || "/");
            }
          } else {
            if (result.errors && !result.errors.password) {
              this.setProperties({
                secondFactorRequired: this.secondFactorRequired,
                securityKeyRequired: this.securityKeyRequired,
                password: null,
                errorMessage: result.message,
              });
            } else if (this.secondFactorRequired || this.securityKeyRequired) {
              this.setProperties({
                secondFactorRequired: false,
                securityKeyRequired: false,
                errorMessage: null,
              });
            } else if (
              result.errors &&
              result.errors.password &&
              result.errors.password.length > 0
            ) {
              this.rejectedPasswords.pushObject(this.accountPassword);
              this.rejectedPasswordsMessages.set(
                this.accountPassword,
                result.errors.password[0]
              );
            }

            if (result.message) {
              this.set("errorMessage", result.message);
            }
          }
        })
        .catch((e) => {
          if (e.jqXHR && e.jqXHR.status === 429) {
            this.set("errorMessage", I18n.t("user.second_factor.rate_limit"));
          } else {
            throw new Error(e);
          }
        });
    },

    authenticateSecurityKey() {
      getWebauthnCredential(
        this.model.challenge,
        this.model.allowed_credential_ids,
        (credentialData) => {
          this.set("securityKeyCredential", credentialData);
          this.send("submit");
        },
        (errorMessage) => {
          this.setProperties({
            securityKeyRequired: true,
            password: null,
            errorMessage,
          });
        }
      );
    },
  },
});
