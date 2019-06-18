import { default as computed } from "ember-addons/ember-computed-decorators";
import { default as DiscourseURL, userPath } from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Ember.Controller.extend({
  loading: false,
  errorMessage: null,
  successMessage: null,
  backupEnabled: Ember.computed.alias("model.second_factor_backup_enabled"),
  remainingCodes: Ember.computed.alias(
    "model.second_factor_remaining_backup_codes"
  ),
  backupCodes: null,
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,

  @computed("secondFactorToken", "secondFactorMethod")
  isValidSecondFactorToken(secondFactorToken, secondFactorMethod) {
    if (secondFactorMethod === SECOND_FACTOR_METHODS.TOTP) {
      return secondFactorToken && secondFactorToken.length === 6;
    } else if (secondFactorMethod === SECOND_FACTOR_METHODS.BACKUP_CODE) {
      return secondFactorToken && secondFactorToken.length === 16;
    }
  },

  @computed("isValidSecondFactorToken", "backupEnabled", "loading")
  isDisabledGenerateBackupCodeBtn(isValid, backupEnabled, loading) {
    return !isValid || loading;
  },

  @computed("isValidSecondFactorToken", "backupEnabled", "loading")
  isDisabledDisableBackupCodeBtn(isValid, backupEnabled, loading) {
    return !isValid || !backupEnabled || loading;
  },

  @computed("backupEnabled")
  generateBackupCodeBtnLabel(backupEnabled) {
    return backupEnabled
      ? "user.second_factor_backup.regenerate"
      : "user.second_factor_backup.enable";
  },

  actions: {
    copyBackupCode(successful) {
      if (successful) {
        this.set(
          "successMessage",
          I18n.t("user.second_factor_backup.copied_to_clipboard")
        );
      } else {
        this.set(
          "errorMessage",
          I18n.t("user.second_factor_backup.copy_to_clipboard_error")
        );
      }

      this._hideCopyMessage();
    },

    disableSecondFactorBackup() {
      this.set("backupCodes", []);

      if (!this.secondFactorToken) return;

      this.set("loading", true);

      this.model
        .toggleSecondFactor(
          this.secondFactorToken,
          this.secondFactorMethod,
          SECOND_FACTOR_METHODS.BACKUP_CODE,
          false
        )
        .then(response => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.set("errorMessage", null);

          const usernameLower = this.model.username.toLowerCase();
          DiscourseURL.redirectTo(userPath(`${usernameLower}/preferences`));
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    },

    generateSecondFactorCodes() {
      if (!this.secondFactorToken) return;
      this.set("loading", true);
      this.model
        .generateSecondFactorCodes(
          this.secondFactorToken,
          this.secondFactorMethod
        )
        .then(response => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.setProperties({
            errorMessage: null,
            backupCodes: response.backup_codes,
            backupEnabled: true,
            remainingCodes: response.backup_codes.length
          });
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.setProperties({
            loading: false,
            secondFactorToken: null
          });
        });
    }
  },

  _hideCopyMessage() {
    Ember.run.later(
      () => this.setProperties({ successMessage: null, errorMessage: null }),
      2000
    );
  }
});
