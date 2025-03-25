<label class="checkbox-label">
  <Input @type="checkbox" disabled={{this.disabled}} @checked={{this.buffer}} />
  {{i18n this.labelKey}}
</label>
{{#if this.changed}}
  <DButton
    @action={{this.apply}}
    @icon="check"
    class="btn-primary btn-small submit-edit"
  />
  <DButton
    @action={{this.cancel}}
    @icon="xmark"
    class="btn-small cancel-edit"
  />
{{/if}}