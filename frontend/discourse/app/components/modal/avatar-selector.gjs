import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AvatarUploader from "discourse/components/avatar-uploader";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";
import { allowsImages, validateUploadedFile } from "discourse/lib/uploads";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import DRadioButton from "discourse/ui-kit/d-radio-button";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AvatarSelectorModal extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked gravatarRefreshDisabled = false;
  @tracked gravatarFailed = false;
  @tracked _selected = null;
  @tracked _pendingFile;
  @tracked _filePreview;

  constructor() {
    super(...arguments);
    if (this.deferSave) {
      const selection = this.args.model.selection;
      this._pendingFile = selection?.file;
      this._filePreview = this._pendingFile
        ? URL.createObjectURL(this._pendingFile)
        : null;
      this._selected =
        selection?.url || (this._pendingFile ? "custom" : "system");
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#clearFilePreview();
  }

  get selected() {
    return this._selected ?? this.defaultSelection;
  }

  set selected(value) {
    this._selected = value;
  }

  get deferSave() {
    return this.args.model.deferSave;
  }

  get systemAvatarTemplate() {
    return this.deferSave
      ? this.args.model.avatarTemplate
      : get(this.user, "system_avatar_template");
  }

  get customAvatarTemplate() {
    return this.deferSave
      ? this._filePreview
      : get(this.user, "custom_avatar_template");
  }

  get user() {
    return this.args.model.user;
  }

  get submitDisabled() {
    return (
      this.selected === "logo" ||
      (this.deferSave && this.selected === "custom" && !this._pendingFile)
    );
  }

  get selectableAvatars() {
    const mode = this.siteSettings.selectable_avatars_mode;
    const list = this.siteSettings.selectable_avatars;
    return mode !== "disabled"
      ? Array.isArray(list)
        ? list
        : list?.split("|") || []
      : null;
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
          this.user?.admin ||
          this.user?.moderator ||
          (this.user?.trust_level ?? 0) >= allowedTl
        );
      case "staff":
        return this.user?.admin || this.user?.moderator;
      case "everyone":
      default:
        return true;
    }
  }

  get defaultSelection() {
    if (this.deferSave) {
      return "system";
    } else if (this.user.use_logo_small_as_avatar) {
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
    if (this.deferSave) {
      return (
        this.args.model.canUploadAvatar &&
        allowsImages(false, this.siteSettings)
      );
    }
    const user = this.currentUser ?? this.user;
    return (
      user.can_upload_avatar && allowsImages(user.staff, this.siteSettings)
    );
  }

  get allowGravatar() {
    return (
      !this.deferSave &&
      this.allowAvatarUpload &&
      this.siteSettings.gravatar_enabled
    );
  }

  @action
  onSelectedChanged(value) {
    this.selected = value;
  }

  afterAvatarSaved({ guardTesting = false } = {}) {
    if (this.args.model.onAvatarChange) {
      this.args.model.onAvatarChange();
      this.args.closeModal?.();
    } else if (!guardTesting || !isTesting()) {
      window.location.reload();
    }
  }

  @action
  async selectAvatar(url, event) {
    event?.preventDefault();
    if (this.deferSave) {
      this.selected = url;
      return;
    }
    try {
      await this.user.selectAvatar(url);
      this.afterAvatarSaved();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  filesPicked(files) {
    const file = files[0];
    if (
      !validateUploadedFile(file, {
        imagesOnly: true,
        siteSettings: this.siteSettings,
      })
    ) {
      return;
    }
    this.#clearFilePreview();
    this._pendingFile = file;
    this._filePreview = URL.createObjectURL(file);
    this.selected = "custom";
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
    if (this.deferSave) {
      let selection = null;
      if (this.selected === "custom") {
        selection = { file: this._pendingFile };
      } else if (this.selected !== "system") {
        selection = { url: this.selected };
      }
      this.args.model.onSelect(selection);
      this.args.closeModal();
      return;
    }
    try {
      await this.user.pickAvatar(this.selectedUploadId, this.selected);
      this.afterAvatarSaved({ guardTesting: true });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #clearFilePreview() {
    if (this._filePreview) {
      URL.revokeObjectURL(this._filePreview);
      this._filePreview = null;
    }
  }

  <template>
    <DModal
      class="avatar-selector-modal"
      @bodyClass="avatar-selector"
      @closeModal={{@closeModal}}
      @title={{i18n "user.change_avatar.title"}}
    >
      <:body>
        {{#if this.showSelectableAvatars}}
          <div class="selectable-avatars">
            {{#each this.selectableAvatars as |avatar|}}
              <a
                aria-current={{if (eq this.selected avatar) "true"}}
                class="selectable-avatar"
                href
                {{on "click" (fn this.selectAvatar avatar)}}
              >
                {{dBoundAvatarTemplate avatar "huge"}}
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
              <DRadioButton
                @id="logo-small"
                @name="logo"
                @onChange={{this.onSelectedChanged}}
                @selection={{this.selected}}
                @value="logo"
              />
              <label class="radio" for="logo-small">
                {{dBoundAvatarTemplate
                  this.siteSettings.site_logo_small_url
                  "large"
                }}
                {{i18n "user.change_avatar.logo_small"}}
              </label>
            </div>
          {{/if}}
          <div class="avatar-choice avatar-choice--system">
            <DRadioButton
              @id="system-avatar"
              @name="avatar"
              @onChange={{this.onSelectedChanged}}
              @selection={{this.selected}}
              @value="system"
            />
            <label class="radio" for="system-avatar">
              {{#if this.systemAvatarTemplate}}
                {{dBoundAvatarTemplate this.systemAvatarTemplate "large"}}
              {{else}}
                <span class="avatar-selector__placeholder">{{dIcon
                    "user"
                  }}</span>
              {{/if}}
              {{i18n "user.change_avatar.letter_based"}}
            </label>
          </div>
          {{#if this.allowGravatar}}
            <div class="avatar-choice avatar-choice--gravatar">
              <DRadioButton
                @id="gravatar"
                @name="avatar"
                @onChange={{this.onSelectedChanged}}
                @selection={{this.selected}}
                @value="gravatar"
              />
              <label class="radio" for="gravatar">
                {{dBoundAvatarTemplate
                  this.user.gravatar_avatar_template
                  "large"
                }}
                <span>
                  {{trustHTML
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
                class="btn-default avatar-selector-refresh-gravatar"
                @action={{this.refreshGravatar}}
                @disabled={{this.gravatarRefreshDisabled}}
                @icon="arrows-rotate"
                @translatedTitle={{i18n
                  "user.change_avatar.refresh_gravatar_title"
                  gravatarName=this.siteSettings.gravatar_name
                }}
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
          {{/if}}
          {{#if this.allowAvatarUpload}}
            <div class="avatar-choice avatar-choice--upload">
              <DRadioButton
                @id="uploaded-avatar"
                @name="avatar"
                @onChange={{this.onSelectedChanged}}
                @selection={{this.selected}}
                @value="custom"
              />
              <label class="radio" for="uploaded-avatar">
                {{#if this.customAvatarTemplate}}
                  {{dBoundAvatarTemplate this.customAvatarTemplate "large"}}
                  {{i18n "user.change_avatar.uploaded_avatar"}}
                {{else}}
                  {{i18n "user.change_avatar.uploaded_avatar_empty"}}
                {{/if}}
              </label>
              {{#if this.deferSave}}
                <DPickFilesButton
                  @acceptedFormatsOverride=".png,.jpg,.jpeg,.gif,.svg,.ico,.heic,.heif,.webp,.avif,.jxl"
                  @currentUser={{hash staff=false}}
                  @fileInputClass="hidden-upload-field"
                  @fileInputId="deferred-avatar-upload"
                  @icon="upload"
                  @label="upload"
                  @onFilesPicked={{this.filesPicked}}
                  @showButton={{true}}
                />
              {{else}}
                <AvatarUploader
                  class="avatar-uploader"
                  @done={{this.uploadComplete}}
                  @id="avatar-uploader"
                  @uploadedAvatarId={{this.user.custom_avatar_upload_id}}
                  @uploadedAvatarTemplate={{this.user.custom_avatar_template}}
                  @user_id={{this.user.id}}
                />
              {{/if}}
            </div>
          {{/if}}
        {{/if}}
      </:body>

      <:footer>
        {{#if (or this.showCustomAvatarSelector this.deferSave)}}
          <DButton
            class="btn-primary"
            @action={{this.saveAvatarSelection}}
            @disabled={{this.submitDisabled}}
            @label="save"
          />
          <DModalCancel @close={{@closeModal}} />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
