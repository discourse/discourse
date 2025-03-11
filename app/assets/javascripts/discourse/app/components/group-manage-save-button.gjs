{{#if this.privateGroupNameNotice}}
  <div class="row">
    <div class="alert alert-warning alert-private-group-name">
      {{this.privateGroupNameNotice}}
    </div>
  </div>
{{/if}}
<div class="control-group buttons group-manage-save-button">
  <DButton
    @action={{this.save}}
    @disabled={{or this.disabled this.saving}}
    @translatedLabel={{this.savingText}}
    class="btn-primary group-manage-save"
  />
  {{#if this.saved}}
    <span>{{i18n "saved"}}</span>
  {{/if}}
</div>