import RestrictedUserRoute from "discourse/routes/restricted-user";
import showModal from "discourse/lib/show-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

export default RestrictedUserRoute.extend({
  model() {
    return this.modelFor("user");
  },

  actions: {
    showAvatarSelector() {
      const props = this.modelFor("user").getProperties(
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

      const controller = showModal("avatar-selector");
      controller.setProperties(props);

      if (this.siteSettings.selectable_avatars_enabled) {
        ajax("/site/selectable-avatars.json").then(avatars =>
          controller.set("selectableAvatars", avatars)
        );
      }
    },

    selectAvatar(url) {
      const user = this.modelFor("user");
      const controller = this.controllerFor("avatar-selector");

      user
        .selectAvatar(url)
        .then(() => bootbox.alert(I18n.t("user.change_avatar.cache_notice")))
        .catch(popupAjaxError)
        .finally(() => controller.send("closeModal"));
    },

    saveAvatarSelection() {
      const user = this.modelFor("user");
      const controller = this.controllerFor("avatar-selector");
      const selectedUploadId = controller.get("selectedUploadId");
      const selectedAvatarTemplate = controller.get("selectedAvatarTemplate");
      const type = controller.get("selected");

      user
        .pickAvatar(selectedUploadId, type, selectedAvatarTemplate)
        .then(() => {
          user.setProperties(
            controller.getProperties(
              "system_avatar_template",
              "gravatar_avatar_template",
              "custom_avatar_template"
            )
          );
          bootbox.alert(I18n.t("user.change_avatar.cache_notice"));
        })
        .catch(popupAjaxError)
        .finally(() => controller.send("closeModal"));
    }
  }
});
