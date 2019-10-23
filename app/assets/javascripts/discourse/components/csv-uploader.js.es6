import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Component.extend(UploadMixin, {
  type: "csv",
  tagName: "span",
  uploadUrl: "/invites/upload_csv",

  validateUploadedFilesOptions() {
    return { csvOnly: true };
  },

  @computed("uploading")
  uploadButtonText(uploading) {
    return uploading
      ? I18n.t("uploading")
      : I18n.t("user.invited.bulk_invite.text");
  },

  @computed("uploading")
  uploadButtonDisabled(uploading) {
    // https://github.com/emberjs/ember.js/issues/10976#issuecomment-132417731
    return uploading ? true : null;
  },

  uploadDone() {
    bootbox.alert(I18n.t("user.invited.bulk_invite.success"));
  },

  uploadOptions() {
    return { autoUpload: false };
  },

  _init: Ember.on("didInsertElement", function() {
    const $upload = $(this.element);

    $upload.on("fileuploadadd", (e, data) => {
      bootbox.confirm(
        I18n.t("user.invited.bulk_invite.confirmation_message"),
        I18n.t("cancel"),
        I18n.t("go_ahead"),
        result => (result ? data.submit() : data.abort())
      );
    });
  })
});
