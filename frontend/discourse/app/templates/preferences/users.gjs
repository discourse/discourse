import { hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import IgnoredUserList from "discourse/components/ignored-user-list";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import UserChooser from "select-kit/components/user-chooser";

export default RouteTemplate(
  <template>
    <label class="control-label">{{i18n "user.users"}}</label>

    {{#if @controller.model.can_ignore_users}}
      <div
        class="control-group user-ignore"
        data-setting-name="user-ignored-users"
      >
        <div class="controls tracking-controls user-notifications">
          <label>{{icon "far-eye-slash" class="icon"}}
            {{i18n "user.ignored_users"}}</label>
          <IgnoredUserList
            @model={{@controller.model}}
            @items={{@controller.model.ignored_usernames}}
          />
        </div>
      </div>
    {{/if}}

    {{#if @controller.model.can_mute_users}}
      <div class="control-group user-mute" data-setting-name="user-muted-users">
        <div class="controls tracking-controls">
          <label>
            {{icon "d-muted" class="icon"}}
            <span>{{i18n "user.muted_users"}}</span>
          </label>
          <UserChooser
            @value={{@controller.mutedUsernames}}
            @onChange={{@controller.onChangeMutedUsernames}}
            @options={{hash excludeCurrentUser=true}}
          />
        </div>
        <div class="instructions">{{i18n "user.muted_users_instructions"}}</div>
      </div>
    {{/if}}

    {{#if @controller.model.can_send_private_messages}}
      <div class="control-group private-messages">
        <label class="control-label">{{i18n "user.private_messages"}}</label>
        <div
          class="control-group user-allow-pm"
          data-setting-name="user-allow-private-messages"
        >
          <div class="controls">
            <PreferenceCheckbox
              @labelKey="user.allow_private_messages"
              @checked={{@controller.model.user_option.allow_private_messages}}
            />
          </div>
        </div>

        <div
          class="control-group user-allow-pm"
          data-setting-name="user-allow-private-messages-from-specific-users"
        >
          <div class="controls">
            <PreferenceCheckbox
              @labelKey="user.allow_private_messages_from_specific_users"
              @checked={{@controller.model.user_option.enable_allowed_pm_users}}
              @disabled={{@controller.disableAllowPmUsersSetting}}
            />
          </div>
          {{#if @controller.allowPmUsersEnabled}}
            <div class="controls tracking-controls">
              <UserChooser
                @value={{@controller.allowedPmUsernames}}
                @onChange={{@controller.onChangeAllowedPmUsernames}}
                @options={{hash excludeCurrentUser=true}}
              />
            </div>
            <div class="instructions">{{i18n
                "user.allowed_pm_users_instructions"
              }}</div>
          {{/if}}
        </div>
      </div>
    {{/if}}

    <span>
      <PluginOutlet
        @name="user-custom-controls"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    <SaveControls
      @model={{@controller.model}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
    />
  </template>
);
