import Controller from "@ember/controller";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { equal, readOnly } from "@ember/object/computed";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import DiscourseURL from "discourse/lib/url";

const { TOTP, BACKUP_CODE, SECURITY_KEY } = SECOND_FACTOR_METHODS;
export default Controller.extend({
  TOTP,
  BACKUP_CODE,
  SECURITY_KEY,

  queryParams: ["nonce"],

  message: null,
  loadError: false,
  messageIsError: false,
  secondFactorToken: null,
  userSelectedMethod: null,

  totpEnabled: readOnly("model.totp_enabled"),
  backupCodesEnabled: readOnly("model.backup_enabled"),
  securityKeysEnabled: readOnly("model.security_keys_enabled"),
  allowedMethods: readOnly("model.allowed_methods"),
  customDescription: readOnly("model.description"),

  showTotpForm: equal("shownSecondFactorMethod", TOTP),
  showSecurityKeyForm: equal("shownSecondFactorMethod", SECURITY_KEY),
  showBackupCodesForm: equal("shownSecondFactorMethod", BACKUP_CODE),

  @discourseComputed("allowedMethods.[]", "totpEnabled")
  totpAvailable() {
    return this.totpEnabled && this.allowedMethods.includes(TOTP);
  },

  @discourseComputed("allowedMethods.[]", "backupCodesEnabled")
  backupCodesAvailable() {
    return this.backupCodesEnabled && this.allowedMethods.includes(BACKUP_CODE);
  },

  @discourseComputed("allowedMethods.[]", "securityKeysEnabled")
  securityKeysAvailable() {
    return (
      this.securityKeysEnabled && this.allowedMethods.includes(SECURITY_KEY)
    );
  },

  @discourseComputed(
    "userSelectedMethod",
    "securityKeysAvailable",
    "totpAvailable",
    "backupCodesAvailable"
  )
  shownSecondFactorMethod(
    userSelectedMethod,
    securityKeysAvailable,
    totpAvailable,
    backupCodesAvailable
  ) {
    if (userSelectedMethod !== null) {
      return userSelectedMethod;
    } else {
      if (securityKeysAvailable) {
        return SECURITY_KEY;
      } else if (totpAvailable) {
        return TOTP;
      } else if (backupCodesAvailable) {
        return BACKUP_CODE;
      } else {
        throw new Error("unexpected state of user 2fa settings!");
      }
    }
  },

  @discourseComputed(
    "shownSecondFactorMethod",
    "securityKeysAvailable",
    "totpAvailable",
    "backupCodesAvailable"
  )
  alternativeMethods(
    shownSecondFactorMethod,
    securityKeysAvailable,
    totpAvailable,
    backupCodesAvailable
  ) {
    const alts = [];
    if (securityKeysAvailable && shownSecondFactorMethod !== SECURITY_KEY) {
      alts.push({
        id: SECURITY_KEY,
        translationKey: "login.second_factor_toggle.security_key",
        class: "security-key",
      });
    }

    if (totpAvailable && shownSecondFactorMethod !== TOTP) {
      alts.push({
        id: TOTP,
        translationKey: "login.second_factor_toggle.totp",
        class: "totp",
      });
    }

    if (backupCodesAvailable && shownSecondFactorMethod !== BACKUP_CODE) {
      alts.push({
        id: BACKUP_CODE,
        translationKey: "login.second_factor_toggle.backup_code",
        class: "backup-code",
      });
    }

    return alts;
  },

  @discourseComputed("shownSecondFactorMethod")
  secondFactorTitle(shownSecondFactorMethod) {
    switch (shownSecondFactorMethod) {
      case TOTP:
        return I18n.t("login.second_factor_title");
      case SECURITY_KEY:
        return I18n.t("login.second_factor_title");
      case BACKUP_CODE:
        return I18n.t("login.second_factor_backup_title");
    }
  },

  @discourseComputed("shownSecondFactorMethod")
  secondFactorDescription(shownSecondFactorMethod) {
    switch (shownSecondFactorMethod) {
      case TOTP:
        return I18n.t("login.second_factor_description");
      case SECURITY_KEY:
        return I18n.t("login.security_key_description");
      case BACKUP_CODE:
        return I18n.t("login.second_factor_backup_description");
    }
  },

  @discourseComputed("messageIsError")
  alertClass(messageIsError) {
    if (messageIsError) {
      return "alert-error";
    } else {
      return "alert-success";
    }
  },

  @discourseComputed("showTotpForm", "showBackupCodesForm")
  inputFormClass(showTotpForm, showBackupCodesForm) {
    if (showTotpForm) {
      return "totp-token";
    } else if (showBackupCodesForm) {
      return "backup-code-token";
    }
  },

  resetState() {
    this.set("message", null);
    this.set("messageIsError", false);
    this.set("secondFactorToken", null);
    this.set("userSelectedMethod", null);
    this.set("loadError", false);
  },

  displayError(message) {
    this.set("message", message);
    this.set("messageIsError", true);
  },

  displaySuccess(message) {
    this.set("message", message);
    this.set("messageIsError", false);
  },

  verifySecondFactor(data) {
    return ajax("/session/2fa", {
      type: "POST",
      data: {
        ...data,
        second_factor_method: this.shownSecondFactorMethod,
        nonce: this.nonce,
      },
    })
      .then((response) => {
        this.displaySuccess(
          I18n.t("second_factor_auth.redirect_after_success")
        );
        ajax(response.callback_path, {
          type: response.callback_method,
          data: { second_factor_nonce: this.nonce },
        })
          .then((callbackResponse) => {
            const redirectUrl =
              callbackResponse.redirect_url || response.redirect_url;
            DiscourseURL.routeTo(redirectUrl);
          })
          .catch((error) => this.displayError(extractError(error)));
      })
      .catch((error) => {
        this.displayError(extractError(error));
      });
  },

  @action
  onTokenInput(event) {
    this.set("secondFactorToken", event.target.value);
  },

  @action
  useAnotherMethod(newMethod, event) {
    event?.preventDefault();
    this.set("userSelectedMethod", newMethod);
  },

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
  },

  @action
  authenticateToken() {
    this.verifySecondFactor({ second_factor_token: this.secondFactorToken });
  },
});
