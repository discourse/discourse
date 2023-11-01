import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { allowsImages } from "discourse/lib/uploads";
import { isTesting } from "discourse-common/config/environment";

export default class AvatarSelectorModal extends Component {
  @service currentUser;
  @service siteSettings;
  @tracked gravatarRefreshDisabled = false;
  @tracked gravatarFailed = false;
  @tracked uploading = false;
  @tracked _selected = null;

  get gravatar() {
    return {
      gravatarName: this.siteSettings.gravatar_name,
      gravatarBaseUrl: this.siteSettings.gravatar_base_url,
      gravatarLoginUrl: this.siteSettings.gravatar_login_url,
    };
  }

  get user() {
    return this.args.model.user;
  }

  get selected() {
    return this._selected ?? this.defaultSelection;
  }

  set selected(value) {
    this._selected = value;
  }

  get submitDisabled() {
    return this.selected === "logo" || this.uploading;
  }

  get selectableAvatars() {
    const mode = this.siteSettings.selectable_avatars_mode;
    const list = this.siteSettings.selectable_avatars;
    return mode !== "disabled" ? (list ? list.split("|") : []) : null;
  }

  get showSelectableAvatars() {
    return this.siteSettings.selectable_avatars_mode !== "disabled";
  }

  get showAvatarUploader() {
    const mode = this.siteSettings.selectable_avatars_mode;
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
  }

  get defaultSelection() {
    if (this.user.use_logo_small_as_avatar) {
      return "logo";
    } else if (this.user.avatar_template === this.user.system_avatar_template) {
      return "system";
    } else if (
      this.user.avatar_template === this.user.gravatar_avatar_template
    ) {
      return "gravatar";
    } else {
      return "custom";
    }
  }

  get selectedUploadId() {
    const selected = this.selected;
    switch (selected) {
      case "system":
        return this.user.system_avatar_upload_id;
      case "gravatar":
        return this.user.gravatar_avatar_upload_id;
      default:
        return this.user.custom_avatar_upload_id;
    }
  }

  get allowAvatarUpload() {
    const allowUploadedAvatars = this.siteSettings.allow_uploaded_avatars;
    return (
      this.siteSettingMatches(allowUploadedAvatars, this.currentUser) &&
      allowsImages(this.currentUser.staff, this.siteSettings)
    );
  }

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
  }

  @action
  onSelectedChanged(value) {
    this.selected = value;
  }

  @action
  async selectAvatar(url, event) {
    event?.preventDefault();
    try {
      await this.user.selectAvatar(url);
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  uploadComplete() {
    this.selected = "custom";
  }

  @action
  async refreshGravatar() {
    this.gravatarRefreshDisabled = true;

    try {
      const result = await ajax(
        `/user_avatar/${this.user.username}/refresh_gravatar.json`,
        {
          type: "POST",
        }
      );

      if (!result.gravatar_upload_id) {
        this.gravatarFailed = true;
      } else {
        this.gravatarFailed = false;
        this.user.setProperties({
          gravatar_avatar_upload_id: result.gravatar_upload_id,
          gravatar_avatar_template: result.gravatar_avatar_template,
        });
      }
    } finally {
      this.gravatarRefreshDisabled = false;
    }
  }

  @action
  async saveAvatarSelection() {
    const selectedUploadId = this.selectedUploadId;
    const type = this.selected;

    try {
      await this.user.pickAvatar(selectedUploadId, type);
      if (!isTesting()) {
        window.location.reload();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
