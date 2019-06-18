import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Ember.Component.extend(UploadMixin, {
  tagName: "span",

  @computed("uploading", "uploadProgress")
  uploadButtonText(uploading, progress) {
    return uploading
      ? I18n.t("admin.backups.upload.uploading_progress", { progress })
      : I18n.t("admin.backups.upload.label");
  },

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  uploadDone() {
    this.done();
  },

  calculateUploadUrl() {
    return "";
  },

  uploadOptions() {
    return {
      type: "PUT",
      dataType: "xml",
      autoUpload: false,
      multipart: false
    };
  },

  _init: function() {
    const $upload = this.$();

    $upload.on("fileuploadadd", (e, data) => {
      ajax("/admin/backups/upload_url", {
        data: { filename: data.files[0].name }
      })
        .then(result => {
          data.url = result.url;
          data.submit();
        })
        .catch(popupAjaxError);
    });
  }.on("didInsertElement")
});
