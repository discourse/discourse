import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { debounce } from "discourse/lib/decorators";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorBackupEdit extends Component {
  @tracked loading = false;
  @tracked errorMessage;
  @tracked successMessage;
  @tracked
  backupEnabled = this.args.model.secondFactor.second_factor_backup_enabled;
  @tracked
  remainingCodes =
    this.args.model.secondFactor.second_factor_remaining_backup_codes;
  @tracked backupCodes;
  @tracked secondFactorMethod = SECOND_FACTOR_METHODS.TOTP;

  @action
  copyBackupCode(successful) {
    if (successful) {
      this.successMessage = i18n(
        "user.second_factor_backup.copied_to_clipboard"
      );
    } else {
      this.errorMessage = i18n(
        "user.second_factor_backup.copy_to_clipboard_error"
      );
    }
    this._hideCopyMessage();
  }

  @action
  generateSecondFactorCodes() {
    this.loading = true;
    this.args.model.secondFactor
      .generateSecondFactorCodes()
      .then((response) => {
        if (response.error) {
          this.errorMessage = response.error;
          return;
        }

        this.args.model.markDirty();
        this.errorMessage = null;
        this.backupCodes = response.backup_codes;
        this.args.model.setBackupEnabled(true);
        this.backupEnabled = true;
        this.remainingCodes = response.backup_codes.length;
        this.args.model.setCodesRemaining(this.remainingCodes);
      })
      .catch((error) => {
        this.args.closeModal();
        this.args.model.onError(error);
      })
      .finally(() => (this.loading = false));
  }

  @debounce(2000)
  _hideCopyMessage() {
    this.successMessage = null;
    this.errorMessage = null;
  }
}
