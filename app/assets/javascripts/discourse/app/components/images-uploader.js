import Component from "@ember/component";
import I18n from "I18n";
import UploadMixin from "discourse/mixins/upload";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UploadMixin, {
  type: "avatar",
  tagName: "span",

  @discourseComputed("uploading")
  uploadButtonText(uploading) {
    return uploading ? I18n.t("uploading") : I18n.t("upload");
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.done(upload);
  },
});
