import Component from "@ember/component";
import { alias, not } from "@ember/object/computed";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  id: "uppy-backup-uploader",
  tagName: "span",
  type: "backup",

  uploadRootPath: "/admin/backups",
  uploadUrl: "/admin/backups/upload",

  // TODO (martin) Add functionality to make this usable _without_ multipart
  // uploads, direct to S3, which needs to call get-presigned-put on the
  // BackupsController (which extends ExternalUploadHelpers) rather than
  // the old create_upload_url route. The two are functionally equivalent;
  // they both generate a presigned PUT url for the upload to S3, and do
  // the whole thing in one request rather than multipart.

  // direct s3 backups
  useMultipartUploadsIfAvailable: not("localBackupStorage"),

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
