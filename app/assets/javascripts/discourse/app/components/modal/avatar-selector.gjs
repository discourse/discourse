import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import AvatarUploader from "discourse/components/avatar-uploader";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import RadioButton from "discourse/components/radio-button";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";
import { allowsImages } from "discourse/lib/uploads";
import { i18n } from "discourse-i18n";

export default class AvatarSelectorModal extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked gravatarRefreshDisabled = false;
  @tracked gravatarFailed = false;
  @tracked uploading = false;
  @tracked _selected = null;

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

  get showCustomAvatarSelector() {
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
    return (
      this.currentUser.can_upload_avatar &&
      allowsImages(this.currentUser.staff, this.siteSettings)
    );
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
    try {
      await this.user.pickAvatar(this.selectedUploadId, this.selected);
      if (!isTesting()) {
        window.location.reload();
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @bodyClass="avatar-selector"
      @closeModal={{@closeModal}}
      @title={{i18n "user.change_avatar.title"}}
      class="avatar-selector-modal"
    >
      <:body>
        {{#if this.showSelectableAvatars}}
          <div class="selectable-avatars">
            {{#each this.selectableAvatars as |avatar|}}
              <a
                href
                class="selectable-avatar"
                {{on "click" (fn this.selectAvatar avatar)}}
              >
                {{boundAvatarTemplate avatar "huge"}}
              </a>
            {{/each}}
          </div>
          {{#if this.showCustomAvatarSelector}}
            <h4>{{i18n "user.change_avatar.use_custom"}}</h4>
          {{/if}}
        {{/if}}
        {{#if this.showCustomAvatarSelector}}
          {{#if this.user.use_logo_small_as_avatar}}
            <div class="avatar-choice">
              <RadioButton
                @id="logo-small"
                @name="logo"
                @value="logo"
                @selection={{this.selected}}
                @onChange={{this.onSelectedChanged}}
              />
              <label class="radio" for="logo-small">
                {{boundAvatarTemplate
                  this.siteSettings.site_logo_small_url
                  "large"
                }}
                {{i18n "user.change_avatar.logo_small"}}
              </label>
            </div>
          {{/if}}
          <div class="avatar-choice">
            <RadioButton
              @id="system-avatar"
              @name="avatar"
              @value="system"
              @selection={{this.selected}}
              @onChange={{this.onSelectedChanged}}
            />
            <label class="radio" for="system-avatar">
              {{boundAvatarTemplate this.user.system_avatar_template "large"}}
              {{i18n "user.change_avatar.letter_based"}}
            </label>
          </div>
          {{#if this.allowAvatarUpload}}
            <div class="avatar-choice">
              <RadioButton
                @id="gravatar"
                @name="avatar"
                @value="gravatar"
                @selection={{this.selected}}
                @onChange={{this.onSelectedChanged}}
              />
              <label class="radio" for="gravatar">
                {{boundAvatarTemplate
                  this.user.gravatar_avatar_template
                  "large"
                }}
                <span>
                  {{htmlSafe
                    (i18n
                      "user.change_avatar.gravatar"
                      gravatarName=this.siteSettings.gravatar_name
                      gravatarBaseUrl=this.siteSettings.gravatar_base_url
                      gravatarLoginUrl=this.siteSettings.gravatar_login_url
                    )
                  }}
                  {{this.user.email}}
                </span>
              </label>

              <DButton
                @action={{this.refreshGravatar}}
                @translatedTitle={{i18n
                  "user.change_avatar.refresh_gravatar_title"
                  gravatarName=this.siteSettings.gravatar_name
                }}
                @disabled={{this.gravatarRefreshDisabled}}
                @icon="arrows-rotate"
                class="btn-default avatar-selector-refresh-gravatar"
              />

              {{#if this.gravatarFailed}}
                <p class="error">
                  {{i18n
                    "user.change_avatar.gravatar_failed"
                    gravatarName=this.siteSettings.gravatar_name
                  }}
                </p>
              {{/if}}
            </div>
            <div class="avatar-choice">
              <RadioButton
                @id="uploaded-avatar"
                @name="avatar"
                @value="custom"
                @selection={{this.selected}}
                @onChange={{this.onSelectedChanged}}
              />
              <label class="radio" for="uploaded-avatar">
                {{#if this.user.custom_avatar_template}}
                  {{boundAvatarTemplate
                    this.user.custom_avatar_template
                    "large"
                  }}
                  {{i18n "user.change_avatar.uploaded_avatar"}}
                {{else}}
                  {{i18n "user.change_avatar.uploaded_avatar_empty"}}
                {{/if}}
              </label>
              <AvatarUploader
                @user_id={{this.user.id}}
                @uploadedAvatarTemplate={{this.user.custom_avatar_template}}
                @uploadedAvatarId={{this.user.custom_avatar_upload_id}}
                @uploading={{this.uploading}}
                @id="avatar-uploader"
                @done={{this.uploadComplete}}
                class="avatar-uploader"
              />
            </div>
          {{/if}}
        {{/if}}
      </:body>

      <:footer>
        {{#if this.showCustomAvatarSelector}}
          <DButton
            @action={{this.saveAvatarSelection}}
            @disabled={{this.submitDisabled}}
            @label="save"
            class="btn-primary"
          />
          <DModalCancel @close={{@closeModal}} />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
