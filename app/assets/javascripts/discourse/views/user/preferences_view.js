/**
  This view handles rendering of a user's preferences

  @class PreferencesView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesView = Discourse.View.extend({
  templateName: 'user/preferences',
  classNames: ['user-preferences'],

  uploading: false,
  uploadProgress: 0,

  customPreferences: function(){
  }.property(),

  didInsertElement: function() {
    var self = this;
    var $upload = $("#profile-background-input");

    this._super();

    $upload.fileupload({
      url: Discourse.getURL("/users/" + this.get('controller.model.username') + "/preferences/user_image"),
      dataType: "json",
      fileInput: $upload,
      formData: { user_image_type: "profile_background" }
    });

    $upload.on('fileuploadsubmit', function (e, data) {
      var result = Discourse.Utilities.validateUploadedFiles(data.files, true);
      self.setProperties({ uploadProgress: 0, uploading: result });
      return result;
    });
    $upload.on("fileuploadprogressall", function(e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      self.set("uploadProgress", progress);
    });
    $upload.on("fileuploaddone", function(e, data) {
      if(data.result.url) {
        self.set("controller.model.profile_background", data.result.url);
      } else {
        bootbox.alert(I18n.t('post.errors.upload'));
      }
    });
    $upload.on("fileuploadfail", function(e, data) {
      Discourse.Utilities.displayErrorForUpload(data);
    });
    $upload.on("fileuploadalways", function() {
      self.setProperties({ uploading: false, uploadProgress: 0});
    });
  },
  willDestroyElement: function() {
    $("#profile-background-input").fileupload("destroy");
  }
});

Discourse.PreferencesView.reopenClass({
  registerCustomSection: function(viewClass){
    var customSections = this.customSections;
    if(!customSections){
      customSections = Em.A();
      this.customSections = customSections;
    }

    customSections.addObject(viewClass);
  }
});

Discourse.CustomPreferences = Discourse.ContainerView.extend({
  init: function(){
    this._super();
    var self = this;

    var sections = Discourse.PreferencesView.customSections;
    if(sections){
      sections.forEach(function(view){
        self.pushObject(view.create({user: self.get('controller.model')}));
      });
    }
  }
});
