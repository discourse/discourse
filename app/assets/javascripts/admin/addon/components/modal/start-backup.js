import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
}
