import ModalFunctionality from 'discourse/mixins/modal-functionality';
import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {
  uploadedAvatarTemplate: null,
  hasUploadedAvatar: Em.computed.or('uploadedAvatarTemplate', 'custom_avatar_upload_id'),

  selectedUploadId: function() {
      switch (this.get("selected")) {
        case "system": return this.get("system_avatar_upload_id");
        case "gravatar": return this.get("gravatar_avatar_upload_id");
        default: return this.get("custom_avatar_upload_id");
      }
  }.property('selected', 'system_avatar_upload_id', 'gravatar_avatar_upload_id', 'custom_avatar_upload_id'),

  actions: {
    useUploadedAvatar() { this.set("selected", "uploaded"); },
    useGravatar() { this.set("selected", "gravatar"); },
    useSystem() { this.set("selected", "system"); },

    refreshGravatar() {
      this.set("gravatarRefreshDisabled", true);
      return Discourse
        .ajax("/user_avatar/" + this.get("username") + "/refresh_gravatar.json", { method: 'POST' })
        .then(result => this.set("gravatar_avatar_upload_id", result.upload_id))
        .finally(() => this.set("gravatarRefreshDisabled", false));
    }
  }

});
