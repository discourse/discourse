import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  id: "uppy-backup-uploader",
  tagName: "span",
  type: "backup",

  uploadRootPath: "/admin/backups",
  uploadUrl: "/admin/backups/upload",

  // direct s3 backups
  @discourseComputed("localBackupStorage")
  useMultipartUploadsIfAvailable(localBackupStorage) {
    return !localBackupStorage && this.siteSettings.enable_direct_s3_uploads;
  },

  // local backups
  useChunkedUploads: alias("localBackupStorage"),

  @discourseComputed("uploading", "uploadProgress")
  uploadButtonText(uploading, progress) {
    return uploading
      ? I18n.t("admin.backups.upload.uploading_progress", { progress })
      : I18n.t("admin.backups.upload.label");
  },

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  uploadDone(responseData) {
    this.done(responseData.file_name);
  },
});
