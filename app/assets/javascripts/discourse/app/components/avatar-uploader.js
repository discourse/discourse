import Component from "@ember/component";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@tagName("span")
export default class AvatarUploader extends Component.extend(UppyUploadMixin) {
  type = "avatar";
  imageIsNotASquare = false;

  @discourseComputed("uploading", "uploadedAvatarId")
  customAvatarUploaded() {
    return !this.uploading && !isBlank(this.uploadedAvatarId);
  }

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  }

  uploadDone(upload) {
    this.setProperties({
      imageIsNotASquare: upload.width !== upload.height,
      uploadedAvatarTemplate: upload.url,
      uploadedAvatarId: upload.id,
    });

    this.done();
  }

  @discourseComputed("user_id")
  data(user_id) {
    return { user_id };
  }

  @discourseComputed("uploading", "uploadProgress")
  uploadLabel() {
    return this.uploading
      ? `${I18n.t("uploading")} ${this.uploadProgress}%`
      : I18n.t("upload");
  }

  @action
  chooseImage() {
    this.fileInputEl.click();
  }
}
