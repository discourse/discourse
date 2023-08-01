import { inject as service } from "@ember/service";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";

export default class TagsUploader extends Component.extend(UppyUploadMixin) {
  @service dialog;
  type = "csv";

  uploadUrl = "/tags/upload";

  @alias("uploading") addDisabled;

  elementId = "tag-uploader";
  preventDirectS3Uploads = true;

  validateUploadedFilesOptions() {
    return { csvOnly: true };
  }

  uploadDone() {
    this.closeModal();
    this.refresh();
    this.dialog.alert(I18n.t("tagging.upload_successful"));
  }
}
