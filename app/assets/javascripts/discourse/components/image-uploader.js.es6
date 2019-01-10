import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  classNames: ["image-uploader"],

  @computed("imageUrl")
  backgroundStyle(imageUrl) {
    if (Em.isEmpty(imageUrl)) {
      return "".htmlSafe();
    }

    return `background-image: url(${imageUrl})`.htmlSafe();
  },

  @computed("backgroundStyle")
  hasBackgroundStyle(backgroundStyle) {
    return !Ember.isEmpty(backgroundStyle.string);
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.setProperties({ imageUrl: upload.url, imageId: upload.id });

    if (this.onUploadDone) {
      this.onUploadDone(upload);
    }
  },

  actions: {
    trash() {
      this.setProperties({ imageUrl: null, imageId: null });

      if (this.onUploadDeleted) {
        this.onUploadDeleted();
      }
    }
  }
});
