import Component from "@ember/component";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  tagName: "span",
  type: "backup",
  useChunkedUploads: true,
  // useMultipartUploadsIfAvailable: true,

  @discourseComputed("uploading", "uploadProgress")
  uploadButtonText(uploading, progress) {
    return uploading
      ? I18n.t("admin.backups.upload.uploading_progress", { progress })
      : I18n.t("admin.backups.upload.label");
  },

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  // TODO (martin) THis is a bit weird, consistency of payload
  uploadDone(responseData) {
    this.done(responseData.fileName);
  },
});
