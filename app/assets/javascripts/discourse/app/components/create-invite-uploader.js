import Component from "@ember/component";
import getUrl from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import {
  displayErrorForUpload,
  validateUploadedFiles,
} from "discourse/lib/uploads";

export default Component.extend({
  tagName: "",

  data: null,
  uploading: false,
  progress: 0,
  uploaded: null,

  @discourseComputed("messageBus.clientId")
  clientId() {
    return this.messageBus && this.messageBus.clientId;
  },

  @discourseComputed("data", "uploading")
  submitDisabled(data, uploading) {
    return !data || uploading;
  },

  didInsertElement() {
    this._super(...arguments);

    this.setProperties({
      data: null,
      uploading: false,
      progress: 0,
      uploaded: null,
    });

    const $upload = $("#csv-file");

    $upload.fileupload({
      url: getUrl("/invites/upload_csv.json") + "?client_id=" + this.clientId,
      dataType: "json",
      dropZone: null,
      replaceFileInput: false,
      autoUpload: false,
    });

    $upload.on("fileuploadadd", (e, data) => {
      this.set("data", data);
    });

    $upload.on("fileuploadsubmit", (e, data) => {
      const isValid = validateUploadedFiles(data.files, {
        user: this.currentUser,
        siteSettings: this.siteSettings,
        bypassNewUserRestriction: true,
        csvOnly: true,
      });

      data.formData = { type: "csv" };
      this.setProperties({ progress: 0, uploading: isValid });

      return isValid;
    });

    $upload.on("fileuploadprogress", (e, data) => {
      const progress = parseInt((data.loaded / data.total) * 100, 10);
      this.set("progress", progress);
    });

    $upload.on("fileuploaddone", (e, data) => {
      const upload = data.result;
      this.set("uploaded", upload);
      this.reset();
    });

    $upload.on("fileuploadfail", (e, data) => {
      if (data.errorThrown !== "abort") {
        displayErrorForUpload(data, this.siteSettings, data.files[0].name);
      }
      this.reset();
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this.messageBus) {
      this.messageBus.unsubscribe("/uploads/csv");
    }

    const $upload = $(this.element);

    try {
      $upload.fileupload("destroy");
    } catch (e) {
      /* wasn't initialized yet */
    } finally {
      $upload.off();
    }
  },

  reset() {
    this.setProperties({
      data: null,
      uploading: false,
      progress: 0,
    });

    document.getElementById("csv-file").value = "";
  },
});
