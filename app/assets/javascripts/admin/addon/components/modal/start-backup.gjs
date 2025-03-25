import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class StartBackup extends Component {
  @service siteSettings;

  @tracked includeUploads = true;

  get canManageUploadsInBackup() {
    return (
      !this.siteSettings.enable_s3_uploads ||
      this.siteSettings.include_s3_uploads_in_backups
    );
  }

  get warningCssClasses() {
    return "";
  }

  get warningMessage() {
    if (
      this.siteSettings.enable_s3_uploads &&
      !this.siteSettings.include_s3_uploads_in_backups
    ) {
      return i18n("admin.backups.operations.backup.s3_upload_warning");
    }
    return "";
  }

  @action
  startBackup() {
    this.args.model.startBackup(this.includeUploads);
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "admin.backups.operations.backup.confirm"}}
      @closeModal={{@closeModal}}
      class="start-backup-modal"
    >
      <:body>
        {{#if this.warningMessage}}
          <div class={{this.warningCssClasses}}>{{htmlSafe
              this.warningMessage
            }}</div>
        {{/if}}
        {{#if this.canManageUploadsInBackup}}
          <label class="checkbox-label">
            <Input @type="checkbox" @checked={{this.includeUploads}} />
            {{i18n "admin.backups.operations.backup.include_uploads"}}
          </label>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.startBackup}}
          @label="yes_value"
        />
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
