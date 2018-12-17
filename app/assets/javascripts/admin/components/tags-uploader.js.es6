import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  type: "csv",
  uploadUrl: "/tags/upload",
  addDisabled: Em.computed.alias("uploading"),
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
