import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import I18n from "I18n";

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
      return I18n.t("admin.backups.operations.backup.s3_upload_warning");
    }
    return "";
  }

  @action
  startBackup() {
    this.args.model.startBackup(this.includeUploads);
    this.args.closeModal();
  }
}
