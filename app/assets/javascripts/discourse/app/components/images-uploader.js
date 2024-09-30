import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@tagName("span")
export default class ImagesUploader extends Component.extend(UppyUploadMixin) {
  type = "avatar";

  @discourseComputed("uploadingOrProcessing")
  uploadButtonText(uploadingOrProcessing) {
    return uploadingOrProcessing ? I18n.t("uploading") : I18n.t("upload");
  }

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  }

  uploadDone(upload) {
    this.done(upload);
  }
}
