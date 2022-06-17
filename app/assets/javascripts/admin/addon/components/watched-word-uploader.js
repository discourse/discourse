import Component from "@ember/component";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { alias } from "@ember/object/computed";
import bootbox from "bootbox";

export default Component.extend(UppyUploadMixin, {
  type: "txt",
  classNames: "watched-words-uploader",
  uploadUrl: "/admin/customize/watched_words/upload",
  addDisabled: alias("uploading"),
  preventDirectS3Uploads: true,

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  _perFileData() {
    return { action_key: this.actionKey };
  },

  uploadDone() {
    if (this) {
      bootbox.alert(I18n.t("admin.watched_words.form.upload_successful"));
      this.done();
    }
  },
});
