import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { alias } from "@ember/object/computed";
import discourseLater from "discourse-common/lib/later";

export default Modal.extend({
  loading: false,
  errorMessage: null,
  successMessage: null,
  backupEnabled: alias("model.second_factor_backup_enabled"),
  remainingCodes: alias("model.second_factor_remaining_backup_codes"),
  backupCodes: null,
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,

  onShow() {
    this.setProperties({
      loading: false,
      errorMessage: null,
      successMessage: null,
      backupCodes: null,
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

    generateSecondFactorCodes() {
      this.set("loading", true);
      this.model
        .generateSecondFactorCodes()
        .then((response) => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }

          this.markDirty();
          this.setProperties({
            errorMessage: null,
            backupCodes: response.backup_codes,
            backupEnabled: true,
            remainingCodes: response.backup_codes.length,
          });
        })
        .catch((error) => {
          this.send("closeModal");
          this.onError(error);
        })
        .finally(() => {
          this.setProperties({
            loading: false,
          });
        });
    },
  },

  _hideCopyMessage() {
    discourseLater(
      () => this.setProperties({ successMessage: null, errorMessage: null }),
      2000
    );
  },
});
