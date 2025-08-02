import { fn, get, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import EmailDropdown from "discourse/components/email-dropdown";
import GoogleIcon from "discourse/components/google-icon";
import PluginOutlet from "discourse/components/plugin-outlet";
import SaveControls from "discourse/components/save-controls";
import TextField from "discourse/components/text-field";
import UserStatusMessage from "discourse/components/user-status-message";
import UsernamePreference from "discourse/components/username-preference";
import boundAvatar from "discourse/helpers/bound-avatar";
import icon from "discourse/helpers/d-icon";
import dasherize from "discourse/helpers/dasherize";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import FlairChooser from "select-kit/components/flair-chooser";

export default RouteTemplate(
  <template>
    <div class="control-group pref-username" data-setting-name="user-username">
      <label class="control-label">{{i18n "user.username.title"}}</label>
      <UsernamePreference @user={{@controller.model}} />
    </div>

    {{#unless @controller.siteSettings.discourse_connect_overrides_avatar}}
      <div class="control-group pref-avatar" data-setting-name="user-avatar">
        <label class="control-label" id="profile-picture">{{i18n
            "user.avatar.title"
          }}</label>
        <input
          type="hidden"
          id="user-avatar-uploads"
          data-custom-avatar-upload-id={{@controller.model.custom_avatar_upload_id}}
          data-system-avatar-upload-id={{@controller.model.system_avatar_upload_id}}
        />
        <div class="controls">
          {{! we want the "huge" version even though we're downsizing it in CSS }}
          {{boundAvatar @controller.model "huge"}}
          <DButton
            @action={{fn (routeAction "showAvatarSelector") @controller.model}}
            @icon="pencil"
            id="edit-avatar"
            class="btn-default pad-left"
          />
        </div>
      </div>
    {{/unless}}

    {{#if @controller.canCheckEmails}}
      <div class="control-group pref-email" data-setting-name="user-email">
        <label class="control-label">{{i18n "user.email.title"}}</label>
        {{#if @controller.model.email}}
          {{#if @controller.siteSettings.enable_secondary_emails}}
            <div class="emails">
              {{#each @controller.emails as |email|}}
                <div class="row email">
                  <div class="email-first">{{email.email}}</div>
                  <div class="email-second">
                    {{#if email.primary}}
                      <span class="primary">
                        {{i18n "user.email.primary_label"}}
                      </span>
                    {{/if}}
                    {{#unless email.confirmed}}
                      <span class="unconfirmed">
                        {{i18n "user.email.unconfirmed_label"}}
                      </span>
                      &bull;
                      {{#if email.resending}}
                        <span>{{i18n "user.email.resending_label"}}</span>
                      {{else if email.resent}}
                        <span>{{i18n "user.email.resent_label"}}</span>
                      {{else}}
                        <button
                          type="button"
                          class="resend-email-confirmation"
                          {{on
                            "click"
                            (fn @controller.resendConfirmationEmail email)
                          }}
                        >
                          {{i18n "user.email.resend_label"}}
                        </button>
                      {{/if}}
                    {{/unless}}
                  </div>
                  {{#if @controller.model.can_edit_email}}
                    <EmailDropdown
                      @email={{email}}
                      @setPrimaryEmail={{@controller.setPrimaryEmail}}
                      @destroyEmail={{@controller.destroyEmail}}
                    />
                  {{/if}}
                </div>
              {{/each}}
            </div>

            {{#if @controller.canAddEmail}}
              <div class="controls">
                <LinkTo @route="preferences.email" @query={{hash new=1}}>
                  {{icon "plus"}}
                  {{i18n "user.email.add_email"}}
                </LinkTo>
              </div>
            {{/if}}
          {{else}}
            <div class="controls">
              <span class="static">{{@controller.model.email}}</span>
              {{#if @controller.model.can_edit_email}}
                <LinkTo
                  @route="preferences.email"
                  class="btn btn-default btn-small btn-icon pad-left no-text"
                >
                  {{icon "pencil"}}
                </LinkTo>
              {{/if}}
            </div>
          {{/if}}

          <div class="instructions">
            {{#if @controller.siteSettings.auth_overrides_email}}
              {{i18n "user.email.auth_override_instructions"}}
            {{/if}}
            {{i18n "user.email.instructions"}}
          </div>
        {{else}}
          <div class="controls">
            <DButton
              @action={{fn (routeAction "checkEmail") @controller.model}}
              @title="admin.users.check_email.title"
              @icon="envelope"
              @label="admin.users.check_email.text"
              class="btn-default"
            />
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{#if @controller.canUpdateAssociatedAccounts}}
      <div
        class="control-group pref-associated-accounts"
        data-setting-name="user-associated-accounts"
      >
        <label class="control-label">{{i18n
            "user.associated_accounts.title"
          }}</label>
        {{#if @controller.associatedAccountsLoaded}}
          <table class="associated-accounts">
            <tbody>
              {{#each @controller.authProviders as |authProvider|}}
                {{#if authProvider.account}}
                  <tr
                    class="{{dasherize authProvider.method.name}}
                      account-connected"
                  >
                    <td class="associated-account__icon">
                      {{#if authProvider.method.isGoogle}}
                        <GoogleIcon />
                      {{else}}
                        {{icon (or authProvider.method.icon "user")}}
                      {{/if}}
                    </td>
                    <td>
                      <div class="associated-account__name">
                        {{#if authProvider.method.provider_url}}
                          <a
                            href={{authProvider.method.provider_url}}
                            rel="noopener noreferrer"
                            target="_blank"
                          >
                            {{authProvider.method.prettyName}}
                          </a>
                        {{else}}
                          {{authProvider.method.prettyName}}
                        {{/if}}
                      </div>
                      <div class="associated-account__description">
                        {{authProvider.account.description}}
                      </div>
                    </td>
                    <td class="associated-account__actions">
                      {{#if authProvider.method.can_revoke}}
                        <DButton
                          @action={{fn
                            @controller.revokeAccount
                            authProvider.account
                          }}
                          @title="user.associated_accounts.revoke"
                          @icon="trash-can"
                          @disabled={{get
                            @controller.revoking
                            authProvider.method.name
                          }}
                          class="btn-danger no-text"
                        />
                      {{/if}}
                    </td>
                  </tr>
                {{else}}
                  <tr class={{dasherize authProvider.method.name}}>
                    <td
                      class="associated-account__icon
                        {{dasherize authProvider.method.name}}"
                    >
                      {{#if authProvider.method.isGoogle}}
                        <GoogleIcon />
                      {{else}}
                        {{icon (or authProvider.method.icon "user")}}
                      {{/if}}
                    </td>
                    <td>
                      <div class="associated-account__name">
                        {{#if authProvider.method.provider_url}}
                          <a
                            href={{authProvider.method.provider_url}}
                            rel="noopener noreferrer"
                            target="_blank"
                          >
                            {{authProvider.method.prettyName}}
                          </a>
                        {{else}}
                          {{authProvider.method.prettyName}}
                        {{/if}}
                      </div>
                      <div class="associated-account__description">
                        {{authProvider.account.description}}
                      </div>
                    </td>
                    <td class="associated-account__actions">
                      {{#if authProvider.method.can_connect}}
                        <DButton
                          @action={{fn
                            @controller.connectAccount
                            authProvider.method
                          }}
                          @label="user.associated_accounts.connect"
                          @icon="plug"
                          @disabled={{@controller.disableConnectButtons}}
                          class="btn-primary"
                        />
                      {{else}}
                        {{i18n "user.associated_accounts.not_connected"}}
                      {{/if}}
                    </td>
                  </tr>
                {{/if}}
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <div class="controls">
            <DButton
              @action={{fn (routeAction "checkEmail") @controller.model}}
              @title="admin.users.check_email.title"
              @icon="envelope"
              @label="admin.users.check_email.text"
            />
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{#if @controller.canEditName}}
      <div class="control-group pref-name" data-setting-name="user-name">
        <label class="control-label">{{i18n "user.name.title"}}</label>
        <div class="controls">
          {{#if @controller.model.can_edit_name}}
            <TextField
              @value={{@controller.newNameInput}}
              @classNames="input-xxlarge"
              @maxlength="255"
            />
          {{else}}
            <span class="static">{{@controller.model.name}}</span>
          {{/if}}
        </div>
        <div class="instructions">
          {{@controller.nameInstructions}}
        </div>
      </div>
    {{/if}}

    {{#if @controller.canSelectTitle}}
      <div class="control-group pref-title" data-setting-name="user-title">
        <label class="control-label">{{i18n "user.title.title"}}</label>
        <div class="controls">
          <ComboBox
            @value={{@controller.newTitleInput}}
            @content={{@controller.model.availableTitles}}
            @onChange={{fn (mut @controller.newTitleInput)}}
            @options={{hash none="user.title.none"}}
          />
        </div>
        <div class="instructions">
          {{i18n "user.title.instructions"}}
        </div>
      </div>
    {{/if}}

    {{#if @controller.canSelectFlair}}
      <div class="control-group pref-flair" data-setting-name="user-flair">
        <label class="control-label">{{i18n "user.flair.title"}}</label>
        <div class="controls">
          <FlairChooser
            @value={{@controller.newFlairGroupId}}
            @content={{@controller.model.availableFlairs}}
            @onChange={{fn (mut @controller.newFlairGroupId)}}
            @options={{hash none="user.flair.none"}}
          />
        </div>
        <div class="instructions">
          {{i18n "user.flair.instructions"}}
        </div>
      </div>
    {{/if}}

    {{#if @controller.canSelectUserStatus}}
      <div
        class="control-group pref-user-status"
        data-setting-name="user-status"
      >
        <label class="control-label">{{i18n "user.status.title"}}</label>
        <div class="controls">
          {{#if @controller.newStatus}}
            <UserStatusMessage
              @status={{@controller.newStatus}}
              @showDescription={{true}}
            />
          {{else}}
            <span class="static">{{i18n "user.status.not_set"}}</span>
          {{/if}}
          <DButton
            @action={{fn @controller.showUserStatusModal @controller.newStatus}}
            @icon="pencil"
            class="btn-default btn-small pad-left"
          />
        </div>
      </div>
    {{/if}}

    {{#if @controller.canSelectPrimaryGroup}}
      <div
        class="control-group pref-primary-group"
        data-setting-name="user-primary-group"
      >
        <label class="control-label">{{i18n "user.primary_group.title"}}</label>
        <div class="controls">
          <ComboBox
            @value={{@controller.newPrimaryGroupInput}}
            @content={{@controller.model.filteredGroups}}
            @options={{hash none="user.primary_group.none"}}
          />
        </div>
      </div>
    {{/if}}

    {{#if @controller.canDownloadPosts}}
      <div
        class="control-group pref-data-export"
        data-setting-name="user-data-export"
      >
        <label class="control-label">{{i18n
            "user.download_archive.title"
          }}</label>
        <div class="controls">
          <DButton
            @action={{@controller.exportUserArchive}}
            @label="user.download_archive.button_text"
            @icon="download"
            class="btn-default btn-request-archive"
          />
        </div>
        <div class="instructions">
          {{i18n "user.download_archive.description"}}
        </div>
      </div>
    {{/if}}

    <span>
      <PluginOutlet
        @name="user-preferences-account"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model save=@controller.save}}
      />
    </span>

    <br />

    <span>
      <PluginOutlet
        @name="user-custom-controls"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    {{#if @controller.canSaveUser}}
      <SaveControls
        @model={{@controller.model}}
        @action={{@controller.save}}
        @saved={{@controller.saved}}
      />
    {{/if}}

    {{#if @controller.model.canDeleteAccount}}
      <div class="control-group delete-account">
        <br />
        <div class="controls">
          <DButton
            @action={{@controller.delete}}
            @disabled={{@controller.deleteDisabled}}
            @icon="trash-can"
            @label="user.delete_account"
            class="btn-danger"
          />
        </div>
      </div>
    {{/if}}
  </template>
);
