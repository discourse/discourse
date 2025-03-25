<div class="setting-label">
  <h3>
    {{this.settingName}}

    {{#if this.staffLogFilter}}
      <LinkTo
        @route="adminLogs.staffActionLogs"
        @query={{hash filters=this.staffLogFilter force_refresh=true}}
        title={{i18n "admin.settings.history"}}
      >
        <span class="history-icon">
          {{d-icon "clock-rotate-left"}}
        </span>
      </LinkTo>
    {{/if}}
  </h3>

  {{#if this.defaultIsAvailable}}
    <DButton
      class="btn-link"
      @action={{this.setDefaultValues}}
      @translatedLabel={{this.setting.setDefaultValuesLabel}}
    />
  {{/if}}
</div>

<div class="setting-value">
  {{#if this.settingEditButton}}
    <DButton
      @action={{this.settingEditButton.action}}
      @icon={{this.settingEditButton.icon}}
      @label={{this.settingEditButton.label}}
      class="setting-value-edit-button"
    />

    <SiteSettings::Description @description={{this.setting.description}} />
  {{else}}
    {{component
      this.componentName
      setting=this.setting
      value=this.buffered.value
      preview=this.preview
      isSecret=this.isSecret
      allowAny=this.allowAny
      changeValueCallback=this.changeValueCallback
      setValidationMessage=this.setValidationMessage
    }}
    <SettingValidationMessage @message={{this.validationMessage}} />
    {{#if this.displayDescription}}
      <SiteSettings::Description @description={{this.setting.description}} />
    {{/if}}
  {{/if}}
</div>

{{#if this.dirty}}
  <div class="setting-controls">
    <DButton
      @action={{this.update}}
      @icon="check"
      @disabled={{this.disableSaveButton}}
      @ariaLabel="admin.settings.save"
      class="ok setting-controls__ok"
    />
    <DButton
      @action={{this.cancel}}
      @icon="xmark"
      @ariaLabel="admin.settings.cancel"
      class="cancel setting-controls__cancel"
    />
  </div>
{{else if this.overridden}}
  {{#if this.setting.secret}}
    <DButton
      @action={{this.toggleSecret}}
      @icon="far-eye-slash"
      @ariaLabel="admin.settings.unmask"
      class="setting-toggle-secret"
    />
  {{/if}}

  <DButton
    class="btn-default undo setting-controls__undo"
    @action={{this.resetDefault}}
    @icon="arrow-rotate-left"
    @label="admin.settings.reset"
  />
{{/if}}