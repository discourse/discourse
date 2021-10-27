import Component from "@ember/component";
// import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  tagName: "span",
  type: "backup",
  useMultipartUploadsIfAvailable: true,

  @discourseComputed("uploading", "uploadProgress")
  uploadButtonText() {
    return "UPPY BACKUP";
    // return uploading
    //   ? I18n.t("admin.backups.upload.uploading_progress", { progress })
    //   : I18n.t("admin.backups.upload.label");
  },

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  uploadDone() {
    this.done();
  },

  // don't think we actually need to do this
  //   uploadOptions() {
  //     return {
  //       type: "PUT",
  //       dataType: "xml",
  //       autoUpload: false,
  //       multipart: false,
  //     };
  //   },

  //   _init: on("didInsertElement", function () {
  //     const $upload = $(this.element);

  //     $upload.on("fileuploadadd", (e, data) => {
  //       ajax("/admin/backups/upload_url", {
  //         data: { filename: data.files[0].name },
  //       })
  //         .then((result) => {
  //           data.url = result.url;
  //           data.submit();
  //         })
  //         .catch(popupAjaxError);
  //     });
  //   }),
});
