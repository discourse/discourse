/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { tagName } from "@ember-decorators/component";
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

  @computed("uppyUpload.filesAwaitingUpload", "uppyUpload.uploading")
  get submitDisabled() {
    return !this.uppyUpload?.filesAwaitingUpload || this.uppyUpload?.uploading;
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
