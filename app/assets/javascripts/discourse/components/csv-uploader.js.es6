import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  type: "csv",
  tagName: "span",
  uploadUrl: "/invites/upload_csv",

  @computed("uploading")
  uploadButtonText(uploading) {
    return uploading ? I18n.t("uploading") : I18n.t("user.invited.bulk_invite.text");
  },

  uploadDone() {
    bootbox.alert(I18n.t("user.invited.bulk_invite.success"));
  }
});
