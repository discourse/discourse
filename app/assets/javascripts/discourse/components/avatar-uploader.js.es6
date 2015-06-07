import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  type: "avatar",
  tagName: "span",
  imageIsNotASquare: false,

  uploadButtonText: function() {
    return this.get("uploading") ? I18n.t("uploading") : I18n.t("user.change_avatar.upload_picture");
  }.property("uploading"),

  uploadDone(upload) {
    this.setProperties({
      imageIsNotASquare: upload.width !== upload.height,
      uploadedAvatarTemplate: upload.url,
      custom_avatar_upload_id: upload.id,
    });

    this.sendAction("done");
  },

  data: function() {
    return { user_id: this.get("user_id") };
  }.property("user_id")
});
