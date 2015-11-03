import computed from 'ember-addons/ember-computed-decorators';
import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  classNames: ["image-uploader"],

  @computed('imageUrl')
  backgroundStyle(imageUrl) {
    if (Em.isNone(imageUrl)) { return; }
    return `background-image: url(${imageUrl})`.htmlSafe();
  },

  uploadDone(upload) {
    this.set("imageUrl", upload.url);
  },

  actions: {
    trash() {
      this.set("imageUrl", null);
    }
  }
});
