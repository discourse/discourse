import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import UploadMixin from "discourse/mixins/upload";

export default Component.extend(UploadMixin, {
  type: "txt",
  classNames: "watched-words-uploader",
  uploadUrl: "/admin/logs/watched_words/upload",
  addDisabled: alias("uploading"),

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
  }
});
