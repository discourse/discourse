import Component from "@ember/component";
import { action } from "@ember/object";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  id: "create-invite-uploader",
  tagName: "div",
  type: "csv",
  autoStartUploads: false,
  uploadUrl: "/invites/upload_csv",
  preventDirectS3Uploads: true,
  fileInputSelector: "#csv-file",

  validateUploadedFilesOptions() {
    return { bypassNewUserRestriction: true, csvOnly: true };
  },

  @discourseComputed("filesAwaitingUpload", "uploading")
  submitDisabled(filesAwaitingUpload, uploading) {
    return !filesAwaitingUpload || uploading;
  },

  uploadDone() {
    this.set("uploaded", true);
  },

  @action
  startUpload() {
    this._startUpload();
  },
});
