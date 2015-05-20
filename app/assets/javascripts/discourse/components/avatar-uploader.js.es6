import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  type: "avatar",
  tagName: "span",
  imageIsNotASquare: false,

  uploadButtonText: function() {
    return this.get("uploading") ? I18n.t("uploading") : I18n.t("user.change_avatar.upload_picture");
  }.property("uploading"),

  uploadDone(upload) {
    // display a warning whenever the image is not a square
    this.set("imageIsNotASquare", upload.width !== upload.height);

    // in order to be as much responsive as possible, we're cheating a bit here
    // indeed, the server gives us back the url to the file we've just uploaded
    // often, this file is not a square, so we need to crop it properly
    // this will also capture the first frame of animated avatars when they're not allowed
    Discourse.Utilities.cropAvatar(upload.url).then(avatarTemplate => {
      this.set("uploadedAvatarTemplate", avatarTemplate);

      // indicates the users is using an uploaded avatar (must happen after cropping, otherwise
      //  we will attempt to load an invalid avatar and cache a redirect to old one, uploadedAvatarTemplate
      //  trumps over custom_avatar_upload_id)
      this.set("custom_avatar_upload_id", upload.id);
    });

    // the upload is now done
    this.sendAction("done");
  }
});
