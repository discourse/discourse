/**
  This controller supports actions related to updating one's avatar

  @class PreferencesAvatarController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesAvatarController = Discourse.ObjectController.extend({
  uploading: false,
  uploadProgress: 0,
  uploadDisabled: Em.computed.or("uploading"),
  useGravatar: Em.computed.not("use_uploaded_avatar"),
  useUploadedAvatar: Em.computed.alias("use_uploaded_avatar"),

  toggleUseUploadedAvatar: function(toggle) {
    if (this.get("use_uploaded_avatar") !== toggle) {
      var controller = this;
      this.set("use_uploaded_avatar", toggle);
      Discourse.ajax("/users/" + this.get("username") + "/preferences/avatar/toggle", { type: 'PUT', data: { use_uploaded_avatar: toggle }})
               .then(function(result) { controller.set("avatar_template", result.avatar_template); });
    }
  },

  uploadButtonText: function() {
    return this.get("uploading") ? I18n.t("user.change_avatar.uploading") : I18n.t("user.change_avatar.upload");
  }.property("uploading"),

  uploadAvatar: function() {
    var controller = this;
    var $upload = $("#avatar-input");

    // do nothing if no file is selected
    if (Em.isEmpty($upload.val())) { return; }

    this.set("uploading", true);

    // define the upload endpoint
    $upload.fileupload({
      url: Discourse.getURL("/users/" + this.get("username") + "/preferences/avatar"),
      dataType: "json",
      timeout: 20000
    });

    // when there is a progression for the upload
    $upload.on("fileuploadprogressall", function (e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      controller.set("uploadProgress", progress);
    });

    // when the upload is successful
    $upload.on("fileuploaddone", function (e, data) {
      // set some properties
      controller.setProperties({
        has_uploaded_avatar: true,
        use_uploaded_avatar: true,
        avatar_template: data.result.url,
        uploaded_avatar_template: data.result.url
      });
    });

    // when there has been an error with the upload
    $upload.on("fileuploadfail", function (e, data) {
      Discourse.Utilities.displayErrorForUpload(data);
    });

    // when the upload is done
    $upload.on("fileuploadalways", function (e, data) {
      // prevent automatic upload when selecting a file
      $upload.fileupload("destroy");
      $upload.off();
      // clear file input
      $upload.val("");
      // indicate upload is done
      controller.setProperties({
        uploading: false,
        uploadProgress: 0
      });
    });

    // *actually* launch the upload
    $("#avatar-input").fileupload("add", { fileInput: $("#avatar-input") });
  }
});
