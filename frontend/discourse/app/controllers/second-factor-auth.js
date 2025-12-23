import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { equal, readOnly } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

const { TOTP, BACKUP_CODE, SECURITY_KEY } = SECOND_FACTOR_METHODS;

export default class SecondFactorAuthController extends Controller {
  TOTP = TOTP;
  BACKUP_CODE = BACKUP_CODE;
  SECURITY_KEY = SECURITY_KEY;
  queryParams = ["nonce"];
  message = null;
  loadError = false;
  messageIsError = false;
  secondFactorToken = null;
  userSelectedMethod = null;
  isLoading = false;

  @readOnly("model.totp_enabled") totpEnabled;
  @readOnly("model.backup_enabled") backupCodesEnabled;
  @readOnly("model.security_keys_enabled") securityKeysEnabled;
  @readOnly("model.allowed_methods") allowedMethods;
  @readOnly("model.description") customDescription;
  @equal("shownSecondFactorMethod", TOTP) showTotpForm;
  @equal("shownSecondFactorMethod", SECURITY_KEY) showSecurityKeyForm;
  @equal("shownSecondFactorMethod", BACKUP_CODE) showBackupCodesForm;

  @computed("allowedMethods.[]", "totpEnabled")
  get totpAvailable() {
    return this.totpEnabled && this.allowedMethods.includes(TOTP);
  }

  @computed("allowedMethods.[]", "backupCodesEnabled")
  get backupCodesAvailable() {
    return this.backupCodesEnabled && this.allowedMethods.includes(BACKUP_CODE);
  }

  @computed("allowedMethods.[]", "securityKeysEnabled")
  get securityKeysAvailable() {
    return (
      this.securityKeysEnabled && this.allowedMethods.includes(SECURITY_KEY)
    );
  }

  @computed(
    "userSelectedMethod",
    "securityKeysAvailable",
    "totpAvailable",
    "backupCodesAvailable"
  )
  get shownSecondFactorMethod() {
    if (this.userSelectedMethod !== null) {
      return this.userSelectedMethod;
    } else {
      if (this.securityKeysAvailable) {
        return SECURITY_KEY;
      } else if (this.totpAvailable) {
        return TOTP;
      } else if (this.backupCodesAvailable) {
        return BACKUP_CODE;
      } else {
        throw new Error("unexpected state of user 2fa settings!");
      }
    }
  }

  @computed(
    "shownSecondFactorMethod",
    "securityKeysAvailable",
    "totpAvailable",
    "backupCodesAvailable"
  )
  get alternativeMethods() {
    const alts = [];
    if (
      this.securityKeysAvailable &&
      this.shownSecondFactorMethod !== SECURITY_KEY
    ) {
      alts.push({
        id: SECURITY_KEY,
        translationKey: "login.second_factor_toggle.security_key",
        class: "security-key",
      });
    }

    if (this.totpAvailable && this.shownSecondFactorMethod !== TOTP) {
      alts.push({
        id: TOTP,
        translationKey: "login.second_factor_toggle.totp",
        class: "totp",
      });
    }

    if (
      this.backupCodesAvailable &&
      this.shownSecondFactorMethod !== BACKUP_CODE
    ) {
      alts.push({
        id: BACKUP_CODE,
        translationKey: "login.second_factor_toggle.backup_code",
        class: "backup-code",
      });
    }

    return alts;
  }

  @computed("shownSecondFactorMethod")
  get secondFactorTitle() {
    switch (this.shownSecondFactorMethod) {
      case TOTP:
        return i18n("login.second_factor_title");
      case SECURITY_KEY:
        return i18n("login.second_factor_title");
      case BACKUP_CODE:
        return i18n("login.second_factor_backup_title");
    }
  }

  @computed("shownSecondFactorMethod")
  get secondFactorDescription() {
    switch (this.shownSecondFactorMethod) {
      case TOTP:
        return i18n("login.second_factor_description");
      case SECURITY_KEY:
        return i18n("login.security_key_description");
      case BACKUP_CODE:
        return i18n("login.second_factor_backup_description");
    }
  }

  @computed("messageIsError")
  get alertClass() {
    if (this.messageIsError) {
      return "alert-error";
    } else {
      return "alert-success";
    }
  }

  @computed("showTotpForm", "showBackupCodesForm")
  get inputFormClass() {
    if (this.showTotpForm) {
      return "totp-token";
    } else if (this.showBackupCodesForm) {
      return "backup-code-token";
    }
  }

  resetState() {
    this.set("message", null);
    this.set("messageIsError", false);
    this.set("secondFactorToken", null);
    this.set("userSelectedMethod", null);
    this.set("loadError", false);
  }

  displayError(message) {
    this.set("message", message);
    this.set("messageIsError", true);
  }

  displaySuccess(message) {
    this.set("message", message);
    this.set("messageIsError", false);
  }

  async verifySecondFactor(data) {
    this.set("isLoading", true);

    try {
      const response = await ajax("/session/2fa", {
        type: "POST",
        data: {
          ...data,
          second_factor_method: this.shownSecondFactorMethod,
          nonce: this.nonce,
        },
      });

      const callbackResponse = await ajax(response.callback_path, {
        type: response.callback_method,
        data: {
          second_factor_nonce: this.nonce,
          ...response.callback_params,
        },
      });

      this.displaySuccess(i18n("second_factor_auth.redirect_after_success"));

      DiscourseURL.routeTo(
        callbackResponse.redirect_url || response.redirect_url
      );
    } catch (error) {
      this.displayError(extractError(error));
    } finally {
      this.set("isLoading", false);
    }
  }

  @action
  useAnotherMethod(newMethod, event) {
    event?.preventDefault();
    this.set("userSelectedMethod", newMethod);
  }

  @action
  authenticateSecurityKey() {
    getWebauthnCredential(
      this.model.challenge,
      this.model.allowed_credential_ids,
      (credentialData) => {
        this.verifySecondFactor({ second_factor_token: credentialData });
      },
      (errorMessage) => {
        this.displayError(errorMessage);
      }
    );
  }

  @computed("secondFactorToken")
  get isSecondFactorTokenValid() {
    return this.secondFactorToken?.length > 0;
  }

  @action
  authenticateToken() {
    this.verifySecondFactor({ second_factor_token: this.secondFactorToken });
  }
}
