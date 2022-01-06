import Component from "@ember/component";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  type: "avatar",
  tagName: "span",

  @discourseComputed("uploadingOrProcessing")
  uploadButtonText(uploadingOrProcessing) {
    return uploadingOrProcessing ? I18n.t("uploading") : I18n.t("upload");
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.done(upload);
  },
});
