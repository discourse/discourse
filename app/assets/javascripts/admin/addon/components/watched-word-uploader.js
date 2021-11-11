import Component from "@ember/component";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { alias } from "@ember/object/computed";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  type: "txt",
  classNames: "watched-words-uploader",
  uploadUrl: "/admin/customize/watched_words/upload",
  addDisabled: alias("uploading"),
  preventDirectS3Uploads: true,

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  @discourseComputed("actionKey")
  data(actionKey) {
    return { action_key: actionKey };
  },

  uploadDone() {
    if (this) {
      bootbox.alert(I18n.t("admin.watched_words.form.upload_successful"));
      this.done();
    }
  },
});
