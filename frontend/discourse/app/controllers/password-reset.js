import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias, or, readOnly } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import PasswordValidationHelper from "discourse/lib/password-validation-helper";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class PasswordResetController extends Controller {
  @tracked accountPassword;
  @alias("model.is_developer") isDeveloper;
  @alias("model.admin") admin;
  @alias("model.second_factor_required") secondFactorRequired;
  @alias("model.security_key_required") securityKeyRequired;
  @alias("model.backup_enabled") backupEnabled;
  @or("model.second_factor_required", "model.security_key_required")
  securityKeyOrSecondFactorRequired;
  @readOnly("model.multiple_second_factor_methods") otherMethodAllowed;

  passwordRequired = true;
  errorMessage = null;
  successMessage = null;
  requiresApproval = false;
  redirected = false;
  maskPassword = true;
  passwordValidationHelper = new PasswordValidationHelper(this);
  isLoading = false;

  lockImageUrl = getURL("/images/lock.svg");

  @discourseComputed("securityKeyRequired", "selectedSecondFactorMethod")
  displaySecurityKeyForm(securityKeyRequired, selectedSecondFactorMethod) {
    return (
      securityKeyRequired &&
      selectedSecondFactorMethod === SECOND_FACTOR_METHODS.SECURITY_KEY
    );
  }

  initSelectedSecondFactorMethod() {
    if (this.model.security_key_required) {
      this.set(
        "selectedSecondFactorMethod",
        SECOND_FACTOR_METHODS.SECURITY_KEY
      );
    } else if (this.model.second_factor_required) {
      this.set("selectedSecondFactorMethod", SECOND_FACTOR_METHODS.TOTP);
    } else if (this.model.backup_enabled) {
      this.set("selectedSecondFactorMethod", SECOND_FACTOR_METHODS.BACKUP_CODE);
    }
  }

  get passwordValidation() {
    return this.passwordValidationHelper.passwordValidation;
  }

  @discourseComputed()
  continueButtonText() {
    return i18n("password_reset.continue", {
      site_name: this.siteSettings.title,
    });
  }

  @discourseComputed("redirectTo")
  redirectHref(redirectTo) {
    return getURL(redirectTo || "/");
  }

  get showPasswordValidation() {
    return this.passwordValidation.ok || this.passwordValidation.reason;
  }

  @action
  done(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    this.set("redirected", true);
    DiscourseURL.redirectTo(this.redirectTo || "/");
  }

  @action
  togglePasswordMask() {
    this.toggleProperty("maskPassword");
  }

  @action
  async submit() {
    try {
      this.set("isLoading", true);

      const result = await ajax({
        url: userPath(`password-reset/${this.get("model.token")}.json`),
        type: "PUT",
        data: {
          password: this.accountPassword,
          second_factor_token:
            this.securityKeyCredential || this.secondFactorToken,
          second_factor_method: this.selectedSecondFactorMethod,
          timezone: moment.tz.guess(),
        },
      });

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
        if (result.errors.security_keys || result.errors.user_second_factors) {
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
        } else if (result.errors?.["user_password.password"]?.length > 0) {
          this.passwordValidationHelper.rejectedPasswords.push(
            this.accountPassword
          );
          this.passwordValidationHelper.rejectedPasswordsMessages.set(
            this.accountPassword,
            (result.friendly_messages || []).join("\n")
          );
        }

        if (result.message) {
          this.set("errorMessage", result.message);
        }
      }
    } catch (e) {
      if (e.jqXHR?.status === 429) {
        this.set("errorMessage", i18n("user.second_factor.rate_limit"));
      } else {
        throw new Error(e);
      }
    } finally {
      this.set("isLoading", false);
    }
  }

  @action
  authenticateSecurityKey() {
    this.set("selectedSecondFactorMethod", SECOND_FACTOR_METHODS.SECURITY_KEY);

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
  }
}
