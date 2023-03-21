import Controller from "@ember/controller";
import { action } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { allowsImages } from "discourse/lib/uploads";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { setting } from "discourse/lib/computed";
import { isTesting } from "discourse-common/config/environment";
import { dependentKeyCompat } from "@ember/object/compat";
import { tracked } from "@glimmer/tracking";

export default Controller.extend(ModalFunctionality, {
  gravatarName: setting("gravatar_name"),
  gravatarBaseUrl: setting("gravatar_base_url"),
  gravatarLoginUrl: setting("gravatar_login_url"),

  @discourseComputed("selected", "uploading")
  submitDisabled(selected, uploading) {
    return selected === "logo" || uploading;
  },

  @discourseComputed(
    "siteSettings.selectable_avatars_mode",
    "siteSettings.selectable_avatars"
  )
  selectableAvatars(mode, list) {
    if (mode !== "disabled") {
      return list ? list.split("|") : [];
    }
  },

  @discourseComputed("siteSettings.selectable_avatars_mode")
  showSelectableAvatars(mode) {
    return mode !== "disabled";
  },

  @discourseComputed("siteSettings.selectable_avatars_mode")
  showAvatarUploader(mode) {
    switch (mode) {
      case "no_one":
        return false;
      case "tl1":
      case "tl2":
      case "tl3":
      case "tl4":
        const allowedTl = parseInt(mode.replace("tl", ""), 10);
        return (
          this.user.admin ||
          this.user.moderator ||
          this.user.trust_level >= allowedTl
        );
      case "staff":
        return this.user.admin || this.user.moderator;
      case "everyone":
      default:
        return true;
    }
  },

  @tracked _selected: null,

  @dependentKeyCompat
  get selected() {
    return this._selected ?? this.defaultSelection;
  },

  set selected(value) {
    this._selected = value;
  },

  @action
  onSelectedChanged(value) {
    this._selected = value;
  },

  get defaultSelection() {
    if (this.get("user.use_logo_small_as_avatar")) {
      return "logo";
    } else if (
      this.get("user.avatar_template") ===
      this.get("user.system_avatar_template")
    ) {
      return "system";
    } else if (
      this.get("user.avatar_template") ===
      this.get("user.gravatar_avatar_template")
    ) {
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

  @action
  selectAvatar(url, event) {
    event?.preventDefault();
    this.user
      .selectAvatar(url)
      .then(() => window.location.reload())
      .catch(popupAjaxError);
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

    saveAvatarSelection() {
      const selectedUploadId = this.selectedUploadId;
      const type = this.selected;

      this.user
        .pickAvatar(selectedUploadId, type)
        .then(() => {
          if (!isTesting()) {
            window.location.reload();
          }
        })
        .catch(popupAjaxError);
    },
  },
});
