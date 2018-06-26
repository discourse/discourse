import { default as computed } from "ember-addons/ember-computed-decorators";
import { default as DiscourseURL, userPath } from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  loading: false,
  errorMessage: null,
  successMessage: null,
  backupEnabled: Ember.computed.alias("model.second_factor_backup_enabled"),
  backupCodes: null,

  @computed("secondFactorToken")
  isValidSecondFactorToken(secondFactorToken) {
    return secondFactorToken && secondFactorToken.length === 6;
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
      // hide copy-to-clipboard success/error message after 2s
      Ember.run.later(
        () => this.setProperties({ successMessage: null, errorMessage: null }),
        2000
      );
    },

    disableSecondFactorBackup() {
      this.set("backupCodes", []);

      if (!this.get("secondFactorToken")) return;

      this.set("loading", true);

      this.get("content")
        .toggleSecondFactor(this.get("secondFactorToken"), false, 2)
        .then(response => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.set("errorMessage", null);

          const usernameLower = this.get("content").username.toLowerCase();
          DiscourseURL.redirectTo(userPath(`${usernameLower}/preferences`));
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    },

    generateSecondFactorCodes() {
      if (!this.get("secondFactorToken")) return;
      const model = this.get("model");
      this.set("loading", true);
      this.get("content")
        .generateSecondFactorCodes(this.get("secondFactorToken"))
        .then(response => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.setProperties({
            errorMessage: null,
            backupCodes: response.backup_codes
          });
          model.set("second_factor_backup_enabled", true);
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.setProperties({
            loading: false,
            secondFactorToken: null
          });
        });
    }
  }
});
