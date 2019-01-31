import UploadMixin from "discourse/mixins/upload";

export default Ember.Component.extend(UploadMixin, {
  type: "csv",
  uploadUrl: "/tags/upload",
  addDisabled: Ember.computed.alias("uploading"),
  elementId: "tag-uploader",

  validateUploadedFilesOptions() {
    return { csvOnly: true };
  },

  uploadDone() {
    bootbox.alert(I18n.t("tagging.upload_successful"), () => {
      this.refresh();
      this.closeModal();
    });
  }
});
