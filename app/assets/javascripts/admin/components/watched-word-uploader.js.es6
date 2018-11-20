import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  type: "csv",
  classNames: "watched-words-uploader",
  uploadUrl: "/admin/logs/watched_words/upload",
  addDisabled: Em.computed.alias("uploading"),

  validateUploadedFilesOptions() {
    return { csvOnly: true };
  },

  @computed("actionKey")
  data(actionKey) {
    return { action_key: actionKey };
  },

  uploadDone() {
    if (this) {
      bootbox.alert(I18n.t("admin.watched_words.form.upload_successful"));
      this.sendAction("done");
    }
  }
});
