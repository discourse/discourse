import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { allowsImages } from "discourse/lib/uploads";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { setting } from "discourse/lib/computed";

export default Controller.extend(ModalFunctionality, {
  gravatarName: setting("gravatar_name"),
  gravatarBaseUrl: setting("gravatar_base_url"),
  gravatarLoginUrl: setting("gravatar_login_url"),

  @discourseComputed("selected", "uploading")
  submitDisabled(selected, uploading) {
    return selected === "logo" || uploading;
  },

  @discourseComputed(
    "siteSettings.selectable_avatars_enabled",
    "siteSettings.selectable_avatars"
  )
  selectableAvatars(enabled, list) {
    if (enabled !== "none") {
      return list ? list.split("|") : [];
    }
  },

  @discourseComputed("siteSettings.selectable_avatars_enabled")
  showSelectableAvatars(enabled) {
    return enabled !== "none";
  },

  @discourseComputed("siteSettings.selectable_avatars_enabled")
  showAvatarUploader(selectableAvatars) {
    if (selectableAvatars === "none") {
      return true;
    }
    if (selectableAvatars === "restrict_all") {
      return false;
    }
    if (selectableAvatars.startsWith("restrict_tl")) {
      const restrictedTl = parseInt(
        selectableAvatars.replace("restrict_tl", ""),
        10
      );
      return (
        this.user.admin ||
        this.user.moderator ||
        this.user.trust_level > restrictedTl
      );
    }
    if (selectableAvatars === "restrict_nonstaff") {
      return this.user.admin || this.user.moderator;
    }
  },

  @discourseComputed(
    "user.use_logo_small_as_avatar",
    "user.avatar_template",
    "user.system_avatar_template",
    "user.gravatar_avatar_template"
  )
  selected(
    useLogo,
    avatarTemplate,
    systemAvatarTemplate,
    gravatarAvatarTemplate
  ) {
    if (useLogo) {
      return "logo";
    } else if (avatarTemplate === systemAvatarTemplate) {
      return "system";
    } else if (avatarTemplate === gravatarAvatarTemplate) {
      return "gravatar";
    } else {
      return "custom";
    }
  },

  @discourseComputed(
    "selected",
    "user.system_avatar_upload_id",
    "user.gravatar_avatar_upload_id",
    "user.custom_avatar_upload_id"
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

  @discourseComputed(
    "selected",
    "user.system_avatar_template",
    "user.gravatar_avatar_template",
    "user.custom_avatar_template"
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

  siteSettingMatches(value, user) {
    switch (value) {
      case "disabled":
        return false;
      case "staff":
        return user.staff;
      case "admin":
        return user.admin;
      default:
        return user.trust_level >= parseInt(value, 10) || user.staff;
    }
  },

  @discourseComputed("siteSettings.allow_uploaded_avatars")
  allowAvatarUpload(allowUploadedAvatars) {
    return (
      this.siteSettingMatches(allowUploadedAvatars, this.currentUser) &&
      allowsImages(this.currentUser.staff, this.siteSettings)
    );
  },

  actions: {
    uploadComplete() {
      this.set("selected", "custom");
    },

    refreshGravatar() {
      this.set("gravatarRefreshDisabled", true);

      return ajax(
        `/user_avatar/${this.get("user.username")}/refresh_gravatar.json`,
        { type: "POST" }
      )
        .then((result) => {
          if (!result.gravatar_upload_id) {
            this.set("gravatarFailed", true);
          } else {
            this.set("gravatarFailed", false);

            this.user.setProperties({
              gravatar_avatar_upload_id: result.gravatar_upload_id,
              gravatar_avatar_template: result.gravatar_avatar_template,
            });
          }
        })
        .finally(() => this.set("gravatarRefreshDisabled", false));
    },

    selectAvatar(url) {
      this.user
        .selectAvatar(url)
        .then(() => window.location.reload())
        .catch(popupAjaxError);
    },

    saveAvatarSelection() {
      const selectedUploadId = this.selectedUploadId;
      const type = this.selected;

      this.user
        .pickAvatar(selectedUploadId, type)
        .then(() => window.location.reload())
        .catch(popupAjaxError);
    },
  },
});
