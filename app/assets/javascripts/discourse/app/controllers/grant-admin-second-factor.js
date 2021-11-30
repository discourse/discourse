import Controller from "@ember/controller";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { getWebauthnCredential } from "discourse/lib/webauthn";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import I18n from "I18n";
import bootbox from "bootbox";

export default Controller.extend(ModalFunctionality, {
  showSecondFactor: false,
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,
  secondFactorToken: null,
  securityKeyCredential: null,

  inProgress: false,

  onShow() {
    this.setProperties({
      showSecondFactor: false,
      secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,
      secondFactorToken: null,
      securityKeyCredential: null,
    });
  },

  @discourseComputed("inProgress", "securityKeyCredential", "secondFactorToken")
  disabled(inProgress, securityKeyCredential, secondFactorToken) {
    return inProgress || (!securityKeyCredential && !secondFactorToken);
  },

  setResult(result) {
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
  },

  @action
  authenticateSecurityKey() {
    getWebauthnCredential(
      this.securityKeyChallenge,
      this.securityKeyAllowedCredentialIds,
      (credentialData) => {
        this.set("securityKeyCredential", credentialData);
        this.send("authenticate");
      },
      (errorMessage) => {
        this.flash(errorMessage, "error");
      }
    );
  },

  @action
  authenticate() {
    this.set("inProgress", true);
    this.model
      .grantAdmin({
        second_factor_token:
          this.securityKeyCredential || this.secondFactorToken,
        second_factor_method: this.secondFactorMethod,
        timezone: moment.tz.guess(),
      })
      .then((result) => {
        if (result.success) {
          this.send("closeModal");
          bootbox.alert(I18n.t("admin.user.grant_admin_success"));
        } else {
          this.flash(result.error, "error");
          this.setResult(result);
        }
      })
      .finally(() => this.set("inProgress", false));
  },
});
