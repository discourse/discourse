{{#if this.canAdminGroup}}
  <div class="control-group">
    <label class="control-label">
      {{i18n "admin.groups.manage.interaction.visibility"}}
    </label>
    <label>
      {{i18n "admin.groups.manage.interaction.visibility_levels.title"}}
    </label>

    <ComboBox
      @name="alias"
      @valueProperty="value"
      @value={{this.model.visibility_level}}
      @content={{this.visibilityLevelOptions}}
      @onChange={{fn (mut this.model.visibility_level)}}
      @options={{hash castInteger=true}}
      class="groups-form-visibility-level"
    />

    <div class="control-instructions">
      {{i18n "admin.groups.manage.interaction.visibility_levels.description"}}
    </div>
  </div>

  <div class="control-group">
    <label>
      {{i18n "admin.groups.manage.interaction.members_visibility_levels.title"}}
    </label>

    <ComboBox
      @name="alias"
      @valueProperty="value"
      @value={{this.membersVisibilityLevel}}
      @content={{this.visibilityLevelOptions}}
      @onChange={{fn (mut this.model.members_visibility_level)}}
      class="groups-form-members-visibility-level"
    />

    {{#if this.membersVisibilityPrivate}}
      <div class="control-instructions">
        {{i18n
          "admin.groups.manage.interaction.members_visibility_levels.description"
        }}
      </div>
    {{/if}}
  </div>
{{/if}}

<div class="control-group">
  <label class="control-label">
    {{i18n "groups.manage.interaction.posting"}}
  </label>
  <label for="alias">{{i18n "groups.alias_levels.mentionable"}}</label>

  <ComboBox
    @name="alias"
    @valueProperty="value"
    @value={{this.mentionableLevel}}
    @content={{this.aliasLevelOptions}}
    @onChange={{fn (mut this.model.mentionable_level)}}
    class="groups-form-mentionable-level"
  />
</div>

<div class="control-group">
  <label for="alias">{{i18n "groups.alias_levels.messageable"}}</label>

  <ComboBox
    @name="alias"
    @valueProperty="value"
    @value={{this.messageableLevel}}
    @content={{this.aliasLevelOptions}}
    @onChange={{fn (mut this.model.messageable_level)}}
    class="groups-form-messageable-level"
  />
</div>

{{#if this.canAdminGroup}}
  <div class="control-group">
    <label>
      <Input
        @type="checkbox"
        @checked={{this.model.publish_read_state}}
        class="groups-form-publish-read-state"
      />

      {{i18n "admin.groups.manage.interaction.publish_read_state"}}
    </label>
  </div>
{{/if}}

{{#if this.showEmailSettings}}
  <div class="control-group">
    <label class="control-label">
      {{i18n "admin.groups.manage.interaction.email"}}
    </label>
    <label for="incoming_email">
      {{i18n "admin.groups.manage.interaction.incoming_email"}}
    </label>

    <TextField
      @name="incoming_email"
      @value={{this.model.incoming_email}}
      @placeholderKey="admin.groups.manage.interaction.incoming_email_placeholder"
      class="input-xxlarge groups-form-incoming-email"
    />

    <DTooltip
      @icon="circle-info"
      @content={{i18n "admin.groups.manage.interaction.incoming_email_tooltip"}}
    />

    <span>
      <PluginOutlet
        @name="group-email-in"
        @connectorTagName="div"
        @outletArgs={{hash model=this.model}}
      />
    </span>
  </div>
{{/if}}

<label class="control-label">
  {{i18n "groups.manage.interaction.notification"}}
</label>

<div class="control-group">
  <label>{{i18n "groups.notification_level"}}</label>

  <NotificationsButton
    @value={{this.defaultNotificationLevel}}
    @options={{hash i18nPrefix="groups.notifications"}}
    @onChange={{fn (mut this.model.default_notification_level)}}
    class="groups-form-default-notification-level"
  />
</div>

<span>
  <PluginOutlet
    @name="groups-interaction-custom-options"
    @connectorTagName="div"
    @outletArgs={{hash model=this.model}}
  />
</span>