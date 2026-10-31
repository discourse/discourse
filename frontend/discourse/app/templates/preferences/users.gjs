import { hash } from "@ember/helper";
import IgnoredUserList from "discourse/components/ignored-user-list";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import lazyHash from "discourse/helpers/lazy-hash";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

export default <template>
  <label class="control-label">{{i18n "user.users"}}</label>

  {{#if @controller.model.can_ignore_users}}
    <div
      class="control-group user-ignore"
      data-setting-name="user-ignored-users"
    >
      <div class="controls tracking-controls user-notifications">
        <label>{{dIcon "far-eye-slash" class="icon"}}
          {{i18n "user.ignored_users"}}</label>
        <IgnoredUserList
          @items={{@controller.model.ignored_usernames}}
          @model={{@controller.model}}
        />
      </div>
    </div>
  {{/if}}

  {{#if @controller.model.can_mute_users}}
    <div class="control-group user-mute" data-setting-name="user-muted-users">
      <div class="controls tracking-controls">
        <label>
          {{dIcon "d-muted" class="icon"}}
          <span>{{i18n "user.muted_users"}}</span>
        </label>
        {{! TODO (select-kit-replacement-cleanup) }}
        {{#if @controller.siteSettings.enable_new_select_controls}}
          <DSelectUser
            @excludeCurrentUser={{true}}
            @multiple={{true}}
            @onChange={{@controller.onChangeMutedUsernames}}
            @texts={{hash ariaLabel=(i18n "user.muted_users")}}
            @value={{@controller.mutedUsernames}}
          />
        {{else}}
          {{! TODO (select-kit-replacement-cleanup) }}
          <UserChooser
            @onChange={{@controller.onChangeMutedUsernames}}
            @options={{hash excludeCurrentUser=true}}
            @value={{@controller.mutedUsernames}}
          />
        {{/if}}
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
            @checked={{@controller.model.user_option.allow_private_messages}}
            @labelKey="user.allow_private_messages"
          />
        </div>
      </div>

      <div
        class="control-group user-allow-pm"
        data-setting-name="user-allow-private-messages-from-specific-users"
      >
        <div class="controls">
          <PreferenceCheckbox
            @checked={{@controller.model.user_option.enable_allowed_pm_users}}
            @disabled={{@controller.disableAllowPmUsersSetting}}
            @labelKey="user.allow_private_messages_from_specific_users"
          />
        </div>
        {{#if @controller.allowPmUsersEnabled}}
          <div class="controls tracking-controls">
            {{! TODO (select-kit-replacement-cleanup) }}
            {{#if @controller.siteSettings.enable_new_select_controls}}
              <DSelectUser
                @excludeCurrentUser={{true}}
                @multiple={{true}}
                @onChange={{@controller.onChangeAllowedPmUsernames}}
                @texts={{hash
                  ariaLabel=(i18n
                    "user.allow_private_messages_from_specific_users"
                  )
                }}
                @value={{@controller.allowedPmUsernames}}
              />
            {{else}}
              {{! TODO (select-kit-replacement-cleanup) }}
              <UserChooser
                @onChange={{@controller.onChangeAllowedPmUsernames}}
                @options={{hash excludeCurrentUser=true}}
                @value={{@controller.allowedPmUsernames}}
              />
            {{/if}}
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
      @connectorTagName="div"
      @name="user-custom-controls"
      @outletArgs={{lazyHash model=@controller.model}}
    />
  </span>

  <DSaveControls
    @action={{@controller.save}}
    @model={{@controller.model}}
    @saved={{@controller.saved}}
  />
</template>
