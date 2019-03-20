import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Ember.Component.extend(UploadMixin, {
  type: "avatar",
  tagName: "span",

  @computed("uploading")
  uploadButtonText(uploading) {
    return uploading
      ? I18n.t("uploading")
      : I18n.t("user.change_avatar.upload_picture");
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.done(upload);
  }
});
