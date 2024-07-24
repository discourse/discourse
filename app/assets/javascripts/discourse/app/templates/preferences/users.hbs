<label class="control-label">{{i18n "user.users"}}</label>

{{#if this.model.can_ignore_users}}
  <div class="control-group user-ignore" data-setting-name="user-ignored-users">
    <div class="controls tracking-controls user-notifications">
      <label>{{d-icon "far-eye-slash" class="icon"}}
        {{i18n "user.ignored_users"}}</label>
      <IgnoredUserList
        @model={{this.model}}
        @items={{this.model.ignored_usernames}}
      />
    </div>
  </div>
{{/if}}

{{#if this.model.can_mute_users}}
  <div class="control-group user-mute" data-setting-name="user-muted-users">
    <div class="controls tracking-controls">
      <label>
        {{d-icon "d-muted" class="icon"}}
        <span>{{i18n "user.muted_users"}}</span>
      </label>
      <UserChooser
        @value={{this.mutedUsernames}}
        @onChange={{action "onChangeMutedUsernames"}}
        @options={{hash excludeCurrentUser=true}}
      />
    </div>
    <div class="instructions">{{i18n "user.muted_users_instructions"}}</div>
  </div>
{{/if}}

{{#if this.model.can_send_private_messages}}
  <div class="control-group private-messages">
    <label class="control-label">{{i18n "user.private_messages"}}</label>
    <div
      class="control-group user-allow-pm"
      data-setting-name="user-allow-private-messages"
    >
      <div class="controls">
        <PreferenceCheckbox
          @labelKey="user.allow_private_messages"
          @checked={{this.model.user_option.allow_private_messages}}
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
          @checked={{this.model.user_option.enable_allowed_pm_users}}
          @disabled={{this.disableAllowPmUsersSetting}}
        />
      </div>
      {{#if this.allowPmUsersEnabled}}
        <div class="controls tracking-controls">
          <UserChooser
            @value={{this.allowedPmUsernames}}
            @onChange={{action "onChangeAllowedPmUsernames"}}
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
    @outletArgs={{hash model=this.model}}
  />
</span>

<SaveControls
  @model={{this.model}}
  @action={{action "save"}}
  @saved={{this.saved}}
/>