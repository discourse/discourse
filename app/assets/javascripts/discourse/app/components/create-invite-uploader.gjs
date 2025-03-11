import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import UppyUpload from "discourse/lib/uppy/uppy-upload";

@tagName("div")
export default class CreateInviteUploader extends Component {
  uppyUpload = new UppyUpload(getOwner(this), {
    id: "create-invite-uploader",
    type: "csv",
    autoStartUploads: false,
    uploadUrl: "/invites/upload_csv",
    preventDirectS3Uploads: true,
    validateUploadedFilesOptions: {
      bypassNewUserRestriction: true,
      csvOnly: true,
    },
    uploadDone: () => {
      this.set("uploaded", true);
    },
  });

  @discourseComputed("uppyUpload.filesAwaitingUpload", "uppyUpload.uploading")
  submitDisabled(filesAwaitingUpload, uploading) {
    return !filesAwaitingUpload || uploading;
  }

  @action
  startUpload() {
    this.uppyUpload.startUpload();
  }

  <template>
    {{yield
      (hash
        data=this.data
        uploading=this.uploading
        uploadProgress=this.uploadProgress
        uploaded=this.uploaded
        submitDisabled=this.submitDisabled
        startUpload=this.startUpload
      )
      this.uppyUpload.setup
    }}
  </template>
}
