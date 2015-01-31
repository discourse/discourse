import UploadMixin from 'discourse/mixins/upload';

export default Em.Component.extend(UploadMixin, {
  tagName: 'span',
  imageIsNotASquare: false,
  type: 'avatar',

  uploadUrl: Discourse.computed.url('username', '/users/%@/preferences/user_image'),

  uploadButtonText: function() {
    return this.get("uploading") ? I18n.t("uploading") : I18n.t("user.change_avatar.upload_picture");
  }.property("uploading"),

  uploadDone: function(data) {
    var self = this;

    // display a warning whenever the image is not a square
    this.set("imageIsNotASquare", data.result.width !== data.result.height);

    // in order to be as much responsive as possible, we're cheating a bit here
    // indeed, the server gives us back the url to the file we've just uploaded
    // often, this file is not a square, so we need to crop it properly
    // this will also capture the first frame of animated avatars when they're not allowed
    Discourse.Utilities.cropAvatar(data.result.url, data.files[0].type).then(function(avatarTemplate) {
      self.set("uploadedAvatarTemplate", avatarTemplate);

      // indicates the users is using an uploaded avatar (must happen after cropping, otherwise
      //  we will attempt to load an invalid avatar and cache a redirect to old one, uploadedAvatarTemplate
      //  trumps over custom avatar upload id)
      self.set("custom_avatar_upload_id", data.result.upload_id);
    });

    // the upload is now done
    this.sendAction("done");
  }
});
