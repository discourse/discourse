import Component from "@ember/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { isBlank } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@tagName("span")
export default class AvatarUploader extends Component {
  uppyUpload = new UppyUpload(getOwner(this), {
    id: "avatar-uploader",
    type: "avatar",
    validateUploadedFilesOptions: {
      imagesOnly: true,
    },
    uploadDone: (upload) => {
      this.setProperties({
        imageIsNotASquare: upload.width !== upload.height,
        uploadedAvatarTemplate: upload.url,
        uploadedAvatarId: upload.id,
      });

      this.done();
    },
    additionalParams: () => ({
      user_id: this.user_id,
    }),
  });

  imageIsNotASquare = false;

  @discourseComputed("uppyUpload.uploading", "uploadedAvatarId")
  customAvatarUploaded() {
    return !this.uppyUpload.uploading && !isBlank(this.uploadedAvatarId);
  }

  @discourseComputed("uppyUpload.uploading", "uppyUpload.uploadProgress")
  uploadLabel() {
    return this.uppyUpload.uploading
      ? `${I18n.t("uploading")} ${this.uppyUpload.uploadProgress}%`
      : I18n.t("upload");
  }

  @action
  chooseImage() {
    this.uppyUpload.openPicker();
  }
}
