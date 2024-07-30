import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import I18n from "discourse-i18n";

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
