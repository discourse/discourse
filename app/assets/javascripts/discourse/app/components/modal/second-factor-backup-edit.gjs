import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import BackupCodes from "discourse/components/backup-codes";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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

  <template>
    <DModal
      @title={{i18n "user.second_factor_backup.title"}}
      @closeModal={{@closeModal}}
      class="second-factor-backup-edit-modal"
    >
      <:body>
        {{#if this.successMessage}}
          <div class="alert alert-success">
            {{this.successMessage}}
          </div>
        {{/if}}

        {{#if this.errorMessage}}
          <div class="alert alert-error">
            {{this.errorMessage}}
          </div>
        {{/if}}

        <ConditionalLoadingSection @isLoading={{this.loading}}>
          {{#if this.backupCodes}}
            <h3>{{i18n "user.second_factor_backup.codes.title"}}</h3>
            <p>{{i18n "user.second_factor_backup.codes.description"}}</p>
            <BackupCodes
              @copyBackupCode={{this.copyBackupCode}}
              @backupCodes={{this.backupCodes}}
            />
          {{/if}}
        </ConditionalLoadingSection>

        {{#if this.backupEnabled}}
          {{htmlSafe
            (i18n
              "user.second_factor_backup.remaining_codes"
              count=this.remainingCodes
            )
          }}
        {{else}}
          {{htmlSafe (i18n "user.second_factor_backup.not_enabled")}}
        {{/if}}
      </:body>
      <:footer>
        <div class="actions">
          {{#if this.backupEnabled}}
            <DButton
              class="btn-primary"
              @icon="arrow-rotate-right"
              @action={{this.generateSecondFactorCodes}}
              @type="submit"
              @isLoading={{this.loading}}
              @label="user.second_factor_backup.regenerate"
            />
          {{else}}
            <DButton
              class="btn-primary"
              @action={{this.generateSecondFactorCodes}}
              @type="submit"
              @disabled={{this.loading}}
              @label="user.second_factor_backup.enable"
            />
          {{/if}}
        </div>
      </:footer>
    </DModal>
  </template>
}
