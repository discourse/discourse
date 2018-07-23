import RestrictedUserRoute from "discourse/routes/restricted-user";
import showModal from "discourse/lib/show-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

export default RestrictedUserRoute.extend({
  model() {
    return this.modelFor("user");
  },

  actions: {
    showAvatarSelector(user) {
      user = user || this.modelFor("user");

      const props = user.getProperties(
        "id",
        "email",
        "username",
        "avatar_template",
        "system_avatar_template",
        "gravatar_avatar_template",
        "custom_avatar_template",
        "system_avatar_upload_id",
        "gravatar_avatar_upload_id",
        "custom_avatar_upload_id"
      );

      switch (props.avatar_template) {
        case props.system_avatar_template:
          props.selected = "system";
          break;
        case props.gravatar_avatar_template:
          props.selected = "gravatar";
          break;
        default:
          props.selected = "uploaded";
      }

      props.user = user;

      const controller = showModal("avatar-selector");
      controller.setProperties(props);

      if (this.siteSettings.selectable_avatars_enabled) {
        ajax("/site/selectable-avatars.json").then(avatars =>
          controller.set("selectableAvatars", avatars)
        );
      }
    },

    selectAvatar(url) {
      const controller = this.controllerFor("avatar-selector");
      controller.send("closeModal");

      controller
        .get("user")
        .selectAvatar(url)
        .then(() => window.location.reload())
        .catch(popupAjaxError);
    },

    saveAvatarSelection() {
      const controller = this.controllerFor("avatar-selector");
      const selectedUploadId = controller.get("selectedUploadId");
      const selectedAvatarTemplate = controller.get("selectedAvatarTemplate");
      const type = controller.get("selected");

      controller.send("closeModal");

      controller
        .get("user")
        .pickAvatar(selectedUploadId, type, selectedAvatarTemplate)
        .then(() => window.location.reload())
        .catch(popupAjaxError);
    }
  }
});
