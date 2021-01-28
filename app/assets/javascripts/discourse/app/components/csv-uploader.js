import Component from "@ember/component";
import I18n from "I18n";
import UploadMixin from "discourse/mixins/upload";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { on } from "@ember/object/evented";

export default Component.extend(UploadMixin, {
  type: "csv",
  tagName: "span",
  uploadUrl: "/invites/upload_csv",
  i18nPrefix: "user.invited.bulk_invite",

  validateUploadedFilesOptions() {
    return { csvOnly: true };
  },

  @discourseComputed("uploading")
  uploadButtonText(uploading) {
    return uploading ? I18n.t("uploading") : I18n.t(`${this.i18nPrefix}.text`);
  },

  @discourseComputed("uploading")
  uploadButtonDisabled(uploading) {
    // https://github.com/emberjs/ember.js/issues/10976#issuecomment-132417731
    return uploading ? true : null;
  },

  uploadDone() {
    bootbox.alert(I18n.t(`${this.i18nPrefix}.success`));
  },

  uploadOptions() {
    return { autoUpload: false };
  },

  _init: on("didInsertElement", function () {
    const $upload = $(this.element);

    $upload.on("fileuploadadd", (e, data) => {
      bootbox.confirm(
        I18n.t(`${this.i18nPrefix}.confirmation_message`),
        I18n.t("cancel"),
        I18n.t("go_ahead"),
        (result) => (result ? data.submit() : data.abort())
      );
    });
  }),
});
