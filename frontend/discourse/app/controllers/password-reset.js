import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import PasswordValidationHelper from "discourse/lib/password-validation-helper";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class PasswordResetController extends Controller {
  @tracked accountPassword;

  passwordRequired = true;
  errorMessage = null;
  successMessage = null;
  requiresApproval = false;
  redirected = false;
  maskPassword = true;
  passwordValidationHelper = new PasswordValidationHelper(this);
  isLoading = false;

  lockImageUrl = getURL("/images/lock.svg");

  @computed("model.is_developer")
  get isDeveloper() {
    return this.model?.is_developer;
  }

  set isDeveloper(value) {
    set(this, "model.is_developer", value);
  }

  @computed("model.admin")
  get admin() {
    return this.model?.admin;
  }

  set admin(value) {
    set(this, "model.admin", value);
  }

  @computed("model.second_factor_required")
  get secondFactorRequired() {
    return this.model?.second_factor_required;
  }

  set secondFactorRequired(value) {
    set(this, "model.second_factor_required", value);
  }

  @computed("model.security_key_required")
  get securityKeyRequired() {
    return this.model?.security_key_required;
  }

  set securityKeyRequired(value) {
    set(this, "model.security_key_required", value);
  }

  @computed("model.backup_enabled")
  get backupEnabled() {
    return this.model?.backup_enabled;
  }

  set backupEnabled(value) {
    set(this, "model.backup_enabled", value);
  }

  @computed("model.second_factor_required", "model.security_key_required")
  get securityKeyOrSecondFactorRequired() {
    return (
      this.model?.second_factor_required || this.model?.security_key_required
    );
  }

  @computed("model.multiple_second_factor_methods")
  get otherMethodAllowed() {
    return this.model?.multiple_second_factor_methods;
  }

  @computed("securityKeyRequired", "selectedSecondFactorMethod")
  get displaySecurityKeyForm() {
    return (
      this.securityKeyRequired &&
      this.selectedSecondFactorMethod === SECOND_FACTOR_METHODS.SECURITY_KEY
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

  @computed()
  get continueButtonText() {
    return i18n("password_reset.continue", {
      site_name: this.siteSettings.title,
    });
  }

  @computed("redirectTo")
  get redirectHref() {
    return getURL(this.redirectTo || "/");
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
