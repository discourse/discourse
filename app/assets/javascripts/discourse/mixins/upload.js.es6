export default Em.Mixin.create({
  uploading: false,
  uploadProgress: 0,

  uploadDone: function() {
    Em.warn("You should implement `uploadDone`");
  },

  deleteDone: function() {
    Em.warn("You should implement `deleteDone`");
  },

  _initializeUploader: function() {
    var $upload = this.$(),
        self = this,
        csrf = Discourse.Session.currentProp("csrfToken");

    $upload.fileupload({
      url: this.get('uploadUrl') + ".json?authenticity_token=" + encodeURIComponent(csrf),
      dataType: "json",
      dropZone: $upload,
      pasteZone: $upload
    });

    $upload.on("fileuploaddrop", function (e, data) {
      if (data.files.length > 10) {
        bootbox.alert(I18n.t("post.errors.too_many_dragged_and_dropped_files"));
        return false;
      } else {
        return true;
      }
    });

    $upload.on('fileuploadsubmit', function (e, data) {
      var isValid = Discourse.Utilities.validateUploadedFiles(data.files, true);
      var form = { image_type: self.get('type') };
      if (self.get("data")) { form = $.extend(form, self.get("data")); }
      data.formData = form;
      self.setProperties({ uploadProgress: 0, uploading: isValid });
      return isValid;
    });

    $upload.on("fileuploadprogressall", function(e, data) {
      var progress = parseInt(data.loaded / data.total * 100, 10);
      self.set("uploadProgress", progress);
    });

    $upload.on("fileuploaddone", function(e, data) {
      if (data.result) {
        if (data.result.url) {
          self.uploadDone(data);
        } else {
          if (data.result.message) {
            bootbox.alert(data.result.message);
          } else if (data.result.length > 0) {
            bootbox.alert(data.result.join("\n"));
          } else {
            bootbox.alert(I18n.t('post.errors.upload'));
          }
        }
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
  }.on('didInsertElement'),

  _destroyUploader: function() {
    var $upload = this.$();
    try { $upload.fileupload('destroy'); }
    catch (e) { /* wasn't initialized yet */ }
    $upload.off();
  }.on('willDestroyElement')
});
