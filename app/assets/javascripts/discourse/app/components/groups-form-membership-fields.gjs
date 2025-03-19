<div class="control-group">
  <label class="control-label">{{i18n
      "groups.manage.membership.access"
    }}</label>

  <label>
    <Input
      @type="checkbox"
      class="group-form-public-admission"
      @checked={{this.model.public_admission}}
      disabled={{this.disablePublicSetting}}
    />

    {{i18n "groups.public_admission"}}
  </label>

  <label>
    <Input
      @type="checkbox"
      class="group-form-public-exit"
      @checked={{this.model.public_exit}}
    />

    {{i18n "groups.public_exit"}}
  </label>

  <label>
    <Input
      @type="checkbox"
      class="group-form-allow-membership-requests"
      @checked={{this.model.allow_membership_requests}}
      disabled={{this.disableMembershipRequestSetting}}
    />

    {{i18n "groups.allow_membership_requests"}}
  </label>

  {{#if this.model.allow_membership_requests}}
    <div>
      <label for="membership-request-template">
        {{i18n "groups.membership_request_template"}}
      </label>

      <ExpandingTextArea
        {{on
          "input"
          (with-event-value (fn (mut this.model.membership_request_template)))
        }}
        value={{this.model.membership_request_template}}
        name="membership-request-template"
        class="group-form-membership-request-template input-xxlarge"
      />
    </div>
  {{/if}}
</div>

{{#if this.model.can_admin_group}}
  <div class="control-group">
    <label class="control-label">{{i18n
        "admin.groups.manage.membership.automatic"
      }}</label>

    <label for="automatic_membership">
      {{i18n
        "admin.groups.manage.membership.automatic_membership_email_domains"
      }}
    </label>

    <ListSetting
      @name="automatic_membership"
      @value={{this.emailDomains}}
      @choices={{this.emailDomains}}
      @settingName="name"
      @nameProperty={{null}}
      @valueProperty={{null}}
      @onChange={{action "onChangeEmailDomainsSetting"}}
      @options={{hash allowAny=true}}
      class="group-form-automatic-membership-automatic"
    />

    {{#if this.showAssociatedGroups}}
      <label for="automatic_membership_associated_groups">
        {{i18n
          "admin.groups.manage.membership.automatic_membership_associated_groups"
        }}
      </label>

      <ListSetting
        @name="automatic_membership_associated_groups"
        @value={{this.model.associatedGroupIds}}
        @choices={{this.associatedGroups}}
        @settingName="name"
        @nameProperty="label"
        @valueProperty="id"
        @onChange={{fn (mut this.model.associated_group_ids)}}
        class="group-form-automatic-membership-associated-groups"
      />
    {{/if}}
  </div>

  <span>
    <PluginOutlet
      @name="groups-form-membership-below-automatic"
      @connectorTagName="div"
      @outletArgs={{hash model=this.model}}
    />
  </span>

  <div class="control-group">
    <label class="control-label">{{i18n
        "admin.groups.manage.membership.effects"
      }}</label>
    <label for="grant_trust_level">{{i18n
        "admin.groups.manage.membership.trust_levels_title"
      }}</label>

    <ComboBox
      @name="grant_trust_level"
      @valueProperty="value"
      @value={{this.groupTrustLevel}}
      @content={{this.trustLevelOptions}}
      @onChange={{fn (mut this.model.grant_trust_level)}}
      class="groups-form-grant-trust-level"
    />
    <label>
      <Input
        @type="checkbox"
        @checked={{this.model.primary_group}}
        class="groups-form-primary-group"
      />

      {{i18n "admin.groups.manage.membership.primary_group"}}
    </label>
  </div>

  <div class="control-group">
    <label class="control-label" for="title">
      {{i18n "admin.groups.default_title"}}
    </label>

    <Input @value={{this.model.title}} name="title" class="input-xxlarge" />

    <div class="control-instructions">
      {{i18n "admin.groups.default_title_description"}}
    </div>
  </div>
{{/if}}

{{#if this.canEdit}}
  <div class="control-group">
    <GroupFlairInputs @model={{this.model}} />
  </div>
{{/if}}