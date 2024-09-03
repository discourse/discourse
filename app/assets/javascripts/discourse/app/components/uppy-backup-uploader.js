import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@tagName("span")
export default class UppyBackupUploader extends Component.extend(
  UppyUploadMixin
) {
  id = "uppy-backup-uploader";
  type = "backup";
  uploadRootPath = "/admin/backups";
  uploadUrl = "/admin/backups/upload";

  // local backups
  @alias("localBackupStorage") useChunkedUploads;

  // direct s3 backups
  @discourseComputed("localBackupStorage")
  useMultipartUploadsIfAvailable(localBackupStorage) {
    return !localBackupStorage && this.siteSettings.enable_direct_s3_uploads;
  }

  @discourseComputed("uploading", "uploadProgress")
  uploadButtonText(uploading, progress) {
    return uploading
      ? I18n.t("admin.backups.upload.uploading_progress", { progress })
      : I18n.t("admin.backups.upload.label");
  }

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  }

  uploadDone(responseData) {
    this.done(responseData.file_name);
  }
}
