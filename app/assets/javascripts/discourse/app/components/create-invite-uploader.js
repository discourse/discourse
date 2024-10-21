import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";

@tagName("div")
export default class CreateInviteUploader extends Component.extend(
  UppyUploadMixin
) {
  id = "create-invite-uploader";
  type = "csv";
  autoStartUploads = false;
  uploadUrl = "/invites/upload_csv";
  preventDirectS3Uploads = true;
  fileInputSelector = "#csv-file";

  validateUploadedFilesOptions() {
    return { bypassNewUserRestriction: true, csvOnly: true };
  }

  @discourseComputed("filesAwaitingUpload", "uploading")
  submitDisabled(filesAwaitingUpload, uploading) {
    return !filesAwaitingUpload || uploading;
  }

  uploadDone() {
    this.set("uploaded", true);
  }

  @action
  startUpload() {
    this._startUpload();
  }

  @action
  setElement(element) {
    this.uppyUpload.setup(element);
  }
}
