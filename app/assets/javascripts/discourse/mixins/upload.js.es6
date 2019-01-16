import {
  displayErrorForUpload,
  validateUploadedFiles
} from "discourse/lib/utilities";
import getUrl from "discourse-common/lib/get-url";

export default Ember.Mixin.create({
  uploading: false,
  uploadProgress: 0,

  uploadDone() {
    Ember.warn("You should implement `uploadDone`", {
      id: "discourse.upload.missing-upload-done"
    });
  },

  validateUploadedFilesOptions() {
    return {};
  },

  calculateUploadUrl() {
    return (
      getUrl(this.getWithDefault("uploadUrl", "/uploads")) +
      ".json?client_id=" +
      (this.messageBus && this.messageBus.clientId) +
      "&authenticity_token=" +
      encodeURIComponent(Discourse.Session.currentProp("csrfToken")) +
      this.uploadUrlParams
    );
  },

  uploadUrlParams: "",

  uploadOptions() {
    return {};
  },

  _initialize: function() {
    const $upload = this.$();
    const reset = () =>
      this.setProperties({ uploading: false, uploadProgress: 0 });
    const maxFiles = this.getWithDefault(
      "maxFiles",
      this.siteSettings.simultaneous_uploads
    );

    $upload.on("fileuploaddone", (e, data) => {
      let upload = data.result;
      this.uploadDone(upload);
      reset();
    });

    $upload.fileupload(
      _.merge(
        {
          url: this.calculateUploadUrl(),
          dataType: "json",
          replaceFileInput: false,
          dropZone: $upload,
          pasteZone: $upload
        },
        this.uploadOptions()
      )
    );

    $upload.on("fileuploaddrop", (e, data) => {
      if (maxFiles > 0 && data.files.length > maxFiles) {
        bootbox.alert(
          I18n.t("post.errors.too_many_dragged_and_dropped_files", {
            max: maxFiles
          })
        );
        return false;
      } else {
        return true;
      }
    });

    $upload.on("fileuploadsubmit", (e, data) => {
      const opts = _.merge(
        { bypassNewUserRestriction: true },
        this.validateUploadedFilesOptions()
      );
      const isValid = validateUploadedFiles(data.files, opts);
      const type = this.get("type");
      let form = type ? { type } : {};
      if (this.get("data")) {
        form = $.extend(form, this.get("data"));
      }
      data.formData = form;
      this.setProperties({ uploadProgress: 0, uploading: isValid });
      return isValid;
    });

    $upload.on("fileuploadprogressall", (e, data) => {
      const progress = parseInt((data.loaded / data.total) * 100, 10);
      this.set("uploadProgress", progress);
    });

    $upload.on("fileuploadfail", (e, data) => {
      if (!data || (data && data.errorThrown !== "abort")) {
        displayErrorForUpload(data);
      }
      reset();
    });
  }.on("didInsertElement"),

  _destroy: function() {
    this.messageBus &&
      this.messageBus.unsubscribe("/uploads/" + this.get("type"));

    const $upload = this.$();
    try {
      $upload.fileupload("destroy");
    } catch (e) {
      /* wasn't initialized yet */
    }
    $upload.off();
  }.on("willDestroyElement")
});
