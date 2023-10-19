import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import { dialog } from "discourse/lib/uploads";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import I18n from "discourse-i18n";

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
