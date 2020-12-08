import Component from "@ember/component";
import I18n from "I18n";
import UploadMixin from "discourse/mixins/upload";
import { alias } from "@ember/object/computed";
import bootbox from "bootbox";

export default Component.extend(UploadMixin, {
  type: "csv",
  uploadUrl: "/tags/upload",
  addDisabled: alias("uploading"),
  elementId: "tag-uploader",

  validateUploadedFilesOptions() {
    return { csvOnly: true };
  },

  uploadDone() {
    bootbox.alert(I18n.t("tagging.upload_successful"), () => {
      this.refresh();
      this.closeModal();
    });
  },
});
