/**
  This view handles the avatar selection interface

  @class AvatarSelectorView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.AvatarSelectorView = Discourse.ModalBodyView.extend({
  templateName: 'modal/avatar_selector',
  classNames: ['avatar-selector'],
  title: I18n.t('user.change_avatar.title'),
  uploading: false,
  uploadProgress: 0,
  useGravatar: Em.computed.not("controller.use_uploaded_avatar"),
  canSaveAvatarSelection: Em.computed.or("useGravatar", "controller.has_uploaded_avatar"),
  saveDisabled: Em.computed.not("canSaveAvatarSelection"),
  imageIsNotASquare : false,

  didInsertElement: function() {
    var self = this;
    var $upload = $("#avatar-input");

    this._super();

    // simulate a click on the hidden file input when clicking on our fake file input
    $("#fake-avatar-input").on("click", function(e) {
      // do *NOT* use the cached `$upload` variable, because fileupload is cloning & replacing the input
      // cf. https://github.com/blueimp/jQuery-File-Upload/wiki/Frequently-Asked-Questions#why-is-the-file-input-field-cloned-and-replaced-after-each-selection
      $("#avatar-input").click();
      e.preventDefault();
    });

    // define the upload endpoint
    $upload.fileupload({
      url: Discourse.getURL("/users/" + this.get("controller.username") + "/preferences/avatar"),
      dataType: "json",
      fileInput: $upload
    });

    // when a file has been selected
    $upload.on("fileuploadadd", function (e, data) {
      self.setProperties({
        uploading: true,
        imageIsNotASquare: false
      });
    });

    // when there is a progression for the upload
    $upload.on("fileuploadprogressall", function (e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      self.set("uploadProgress", progress);
    });

    // when the upload is successful
    $upload.on("fileuploaddone", function (e, data) {
      // indicates the users is using an uploaded avatar
      self.get("controller").setProperties({
        has_uploaded_avatar: true,
        use_uploaded_avatar: true
      });
      // display a warning whenever the image is not a square
      self.set("imageIsNotASquare", data.result.width !== data.result.height);
      // in order to be as much responsive as possible, we're cheating a bit here
      // indeed, the server gives us back the url to the file we've just uploaded
      // often, this file is not a square, so we need to crop it properly
      // this will also capture the first frame of animated avatars when they're not allowed
      Discourse.Utilities.cropAvatar(data.result.url, data.files[0].type).then(function(avatarTemplate) {
        self.get("controller").set("uploaded_avatar_template", avatarTemplate);
      });
    });

    // when there has been an error with the upload
    $upload.on("fileuploadfail", function (e, data) {
      Discourse.Utilities.displayErrorForUpload(data);
    });

    // when the upload is done
    $upload.on("fileuploadalways", function (e, data) {
      self.setProperties({ uploading: false, uploadProgress: 0 });
    });
  },

  willDestroyElement: function() {
    $("#fake-avatar-input").off("click");
    $("#avatar-input").fileupload("destroy");
  },

  // *HACK* used to select the proper radio button
  selectedChanged: function() {
    var self = this;
    Em.run.next(function() {
      var value = self.get('controller.use_uploaded_avatar') ? 'uploaded_avatar' : 'gravatar';
      $('input:radio[name="avatar"]').val([value]);
    });
  }.observes('controller.use_uploaded_avatar'),

  uploadButtonText: function() {
    return this.get("uploading") ? I18n.t("uploading") : I18n.t("upload");
  }.property("uploading")

});
