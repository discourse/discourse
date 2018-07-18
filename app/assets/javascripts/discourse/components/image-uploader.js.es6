import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  classNames: ["image-uploader"],

  @computed("imageUrl")
  backgroundStyle(imageUrl) {
    if (Em.isNone(imageUrl)) {
      return "".htmlSafe();
    }
    return `background-image: url(${imageUrl})`.htmlSafe();
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.set("imageUrl", upload.url);
    this.set("imageId", upload.id);
  },

  actions: {
    trash() {
      this.set("imageUrl", null);
      this.set("imageId", null);
    }
  }
});
