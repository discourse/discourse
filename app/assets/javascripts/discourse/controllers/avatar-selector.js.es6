import computed from "ember-addons/ember-computed-decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";

import { allowsImages } from "discourse/lib/utilities";

export default Ember.Controller.extend(ModalFunctionality, {
  @computed(
    "selected",
    "system_avatar_upload_id",
    "gravatar_avatar_upload_id",
    "custom_avatar_upload_id"
  )
  selectedUploadId(selected, system, gravatar, custom) {
    switch (selected) {
      case "system":
        return system;
      case "gravatar":
        return gravatar;
      default:
        return custom;
    }
  },

  @computed(
    "selected",
    "system_avatar_template",
    "gravatar_avatar_template",
    "custom_avatar_template"
  )
  selectedAvatarTemplate(selected, system, gravatar, custom) {
    switch (selected) {
      case "system":
        return system;
      case "gravatar":
        return gravatar;
      default:
        return custom;
    }
  },

  @computed()
  allowAvatarUpload() {
    return this.siteSettings.allow_uploaded_avatars && allowsImages();
  },

  actions: {
    uploadComplete() {
      this.set("selected", "uploaded");
    },

    refreshGravatar() {
      this.set("gravatarRefreshDisabled", true);
      return ajax(
        `/user_avatar/${this.get("username")}/refresh_gravatar.json`,
        { method: "POST" }
      )
        .then(result => {
          if (!result.gravatar_upload_id) {
            this.set("gravatarFailed", true);
          } else {
            this.setProperties({
              gravatarFailed: false,
              gravatar_avatar_template: result.gravatar_avatar_template,
              gravatar_avatar_upload_id: result.gravatar_upload_id
            });
          }
        })
        .finally(() => this.set("gravatarRefreshDisabled", false));
    }
  }
});
