import { classNames } from "@ember-decorators/component";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { dialog } from "discourse/lib/uploads";

@classNames("watched-words-uploader")
export default class WatchedWordUploader extends Component.extend(
  UppyUploadMixin
) {
  type = "txt";
  uploadUrl = "/admin/customize/watched_words/upload";

  @alias("uploading") addDisabled;

  preventDirectS3Uploads = true;

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  }

  _perFileData() {
    return { action_key: this.actionKey };
  }

  uploadDone() {
    if (this) {
      dialog.alert(I18n.t("admin.watched_words.form.upload_successful"));
      this.done();
    }
  }
}
