import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AvatarUploader from "discourse/components/avatar-uploader";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";
import { allowsImages } from "discourse/lib/uploads";
import { findAll as findLoginMethods } from "discourse/models/login-method";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import DRadioButton from "discourse/ui-kit/d-radio-button";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";

const ASSOCIATED_ACCOUNT_AVATAR = "associated_account";

const AvatarChoice = <template>
  <div class="avatar-choice" ...attributes>
    <DRadioButton
      @id={{@id}}
      @name={{or @name "avatar"}}
      @onChange={{@onChange}}
      @selection={{@selection}}
      @value={{@value}}
    />
    <label class="radio" for={{@id}}>
      {{yield}}
    </label>
    {{yield to="action"}}
  </div>
</template>;

export default class AvatarSelectorModal extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked gravatarRefreshDisabled = false;
  @tracked gravatarFailed = false;
  @tracked _selected = null;

  get selected() {
    return this._selected ?? this.defaultSelection;
  }

  get user() {
    return this.args.model.user;
  }

  get submitDisabled() {
    return this.selected === "logo";
  }

  get selectableAvatars() {
    if (!this.showSelectableAvatars) {
      return null;
    }

    const list = this.siteSettings.selectable_avatars;
    return Array.isArray(list) ? list : list?.split("|") || [];
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
        return this.user.staff || this.user.trust_level >= allowedTl;
      case "staff":
        return this.user.staff;
      default:
        return true;
    }
  }

  get associatedAccountAvatars() {
    const methods = findLoginMethods();
    return (this.user.associated_account_avatars || []).map((avatar) => ({
      ...avatar,
      name:
        methods.find(({ name }) => name === avatar.name)?.prettyName ||
        avatar.name,
      selection: `${ASSOCIATED_ACCOUNT_AVATAR}:${avatar.id}`,
    }));
  }

  get defaultSelection() {
    if (this.user.use_logo_small_as_avatar) {
      return "logo";
    }

    const account = this.associatedAccountAvatars.find(
      ({ id }) => id === this.user.selected_user_associated_account_id
    );
    if (account) {
      return account.selection;
    }

    if (
      !this.user.uploaded_avatar_id ||
      this.user.avatar_template === this.user.system_avatar_template
    ) {
      return "system";
    }

    if (this.user.avatar_template === this.user.gravatar_avatar_template) {
      return "gravatar";
    }

    if (this.user.avatar_template === this.user.custom_avatar_template) {
      return "custom";
    }

    return "current";
  }

  get #selectedUploadId() {
    switch (this.selected) {
      case "system":
        return this.user.system_avatar_upload_id;
      case "gravatar":
        return this.user.gravatar_avatar_upload_id;
      case "current":
        return this.user.uploaded_avatar_id;
      default:
        return this.user.custom_avatar_upload_id;
    }
  }

  get allowAvatarUpload() {
    const user = this.currentUser ?? this.user;
    return (
      this.user.can_upload_avatar &&
      user.can_upload_avatar &&
      allowsImages(user.staff, this.siteSettings)
    );
  }

  get allowGravatar() {
    return this.allowAvatarUpload && this.siteSettings.gravatar_enabled;
  }

  @action
  onSelectedChanged(value) {
    this._selected = value;
  }

  @action
  async selectAvatar(url, event) {
    event?.preventDefault();
    try {
      await this.user.selectAvatar(url);
      this.#afterAvatarSaved();
    } catch (error) {
      popupAjaxError(error);
    }
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

      this.gravatarFailed = !result.gravatar_upload_id;
      if (this.gravatarFailed) {
        return;
      }

      this.user.setProperties({
        gravatar_avatar_upload_id: result.gravatar_upload_id,
        gravatar_avatar_template: result.gravatar_avatar_template,
      });
    } finally {
      this.gravatarRefreshDisabled = false;
    }
  }

  @action
  async saveAvatarSelection() {
    const account = this.associatedAccountAvatars.find(
      ({ selection }) => selection === this.selected
    );

    try {
      await this.user.pickAvatar(
        account?.upload_id ?? this.#selectedUploadId,
        account ? ASSOCIATED_ACCOUNT_AVATAR : this.selected,
        account?.id
      );
      this.#afterAvatarSaved();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #afterAvatarSaved() {
    if (this.args.model.onAvatarChange) {
      this.args.model.onAvatarChange();
      this.args.closeModal?.();
    } else if (!isTesting()) {
      window.location.reload();
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
            <AvatarChoice
              @id="logo-small"
              @name="logo"
              @onChange={{this.onSelectedChanged}}
              @selection={{this.selected}}
              @value="logo"
            >
              {{dBoundAvatarTemplate
                this.siteSettings.site_logo_small_url
                "large"
              }}
              {{i18n "user.change_avatar.logo_small"}}
            </AvatarChoice>
          {{/if}}
          <AvatarChoice
            class="avatar-choice--system"
            @id="system-avatar"
            @onChange={{this.onSelectedChanged}}
            @selection={{this.selected}}
            @value="system"
          >
            {{dBoundAvatarTemplate this.user.system_avatar_template "large"}}
            {{i18n "user.change_avatar.letter_based"}}
          </AvatarChoice>
          {{#if this.allowGravatar}}
            <AvatarChoice
              class="avatar-choice--gravatar"
              @id="gravatar"
              @onChange={{this.onSelectedChanged}}
              @selection={{this.selected}}
              @value="gravatar"
            >
              <:default>
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
              </:default>
              <:action>
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
              </:action>
            </AvatarChoice>
          {{/if}}
          {{#if this.allowAvatarUpload}}
            {{#if (eq this.defaultSelection "current")}}
              <AvatarChoice
                class="avatar-choice--current"
                @id="current-avatar"
                @onChange={{this.onSelectedChanged}}
                @selection={{this.selected}}
                @value="current"
              >
                {{dBoundAvatarTemplate this.user.avatar_template "large"}}
                {{i18n "user.change_avatar.current_avatar"}}
              </AvatarChoice>
            {{/if}}
            {{#each this.associatedAccountAvatars as |account|}}
              <AvatarChoice
                class="avatar-choice--associated-account"
                @id={{concat "associated-account-avatar-" account.id}}
                @onChange={{this.onSelectedChanged}}
                @selection={{this.selected}}
                @value={{account.selection}}
              >
                {{dBoundAvatarTemplate account.avatar_template "large"}}
                {{i18n
                  "user.change_avatar.associated_account"
                  provider=account.name
                }}
              </AvatarChoice>
            {{/each}}
            <AvatarChoice
              class="avatar-choice--upload"
              @id="uploaded-avatar"
              @onChange={{this.onSelectedChanged}}
              @selection={{this.selected}}
              @value="custom"
            >
              <:default>
                {{dBoundAvatarTemplate
                  this.user.custom_avatar_template
                  "large"
                }}
                {{#if this.user.custom_avatar_template}}
                  {{i18n "user.change_avatar.uploaded_avatar"}}
                {{else}}
                  {{i18n "user.change_avatar.uploaded_avatar_empty"}}
                {{/if}}
              </:default>
              <:action>
                <AvatarUploader
                  class="avatar-uploader"
                  @done={{fn this.onSelectedChanged "custom"}}
                  @id="avatar-uploader"
                  @uploadedAvatarId={{this.user.custom_avatar_upload_id}}
                  @uploadedAvatarTemplate={{this.user.custom_avatar_template}}
                  @user_id={{this.user.id}}
                />
              </:action>
            </AvatarChoice>
          {{/if}}
        {{/if}}
      </:body>

      <:footer>
        {{#if this.showCustomAvatarSelector}}
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
