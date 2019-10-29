import Controller from "@ember/controller";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,
  successMessage: null,
  backupEnabled: Ember.computed.alias("model.second_factor_backup_enabled"),
  remainingCodes: Ember.computed.alias(
    "model.second_factor_remaining_backup_codes"
  ),
  backupCodes: null,
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,

  @computed("backupEnabled")
  generateBackupCodeBtnLabel(backupEnabled) {
    return backupEnabled
      ? "user.second_factor_backup.regenerate"
      : "user.second_factor_backup.enable";
  },

  onShow() {
    this.setProperties({
      loading: false,
      errorMessage: null,
      successMessage: null,
      backupCodes: null
    });
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
      this.set("loading", true);

      this.model
        .updateSecondFactor(0, "", true, SECOND_FACTOR_METHODS.BACKUP_CODE)
        .then(response => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.set("errorMessage", null);
          this.model.set("second_factor_backup_enabled", false);
          this.markDirty();
          this.send("closeModal");
        })
        .catch(error => {
          this.send("closeModal");
          this.onError(error);
        })
        .finally(() => this.set("loading", false));
    },

    generateSecondFactorCodes() {
      this.set("loading", true);
      this.model
        .generateSecondFactorCodes()
        .then(response => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.markDirty();
          this.setProperties({
            errorMessage: null,
            backupCodes: response.backup_codes,
            backupEnabled: true,
            remainingCodes: response.backup_codes.length
          });
        })
        .catch(error => {
          this.send("closeModal");
          this.onError(error);
        })
        .finally(() => {
          this.setProperties({
            loading: false
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
