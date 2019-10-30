import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Component.extend(UploadMixin, {
  type: "txt",
  classNames: "watched-words-uploader",
  uploadUrl: "/admin/logs/watched_words/upload",
  addDisabled: alias("uploading"),

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  @computed("actionKey")
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
