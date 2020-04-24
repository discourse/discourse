import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import UploadMixin from "discourse/mixins/upload";

export default Component.extend(UploadMixin, {
  type: "avatar",
  tagName: "span",
  imageIsNotASquare: false,

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.setProperties({
      imageIsNotASquare: upload.width !== upload.height,
      uploadedAvatarTemplate: upload.url,
      uploadedAvatarId: upload.id
    });

    this.done();
  },

  @discourseComputed("user_id")
  data(user_id) {
    return { user_id };
  }
});
