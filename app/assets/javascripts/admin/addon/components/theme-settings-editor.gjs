<div class="settings-editor">
  <div>
    <AceEditor
      @content={{this.editedContent}}
      @onChange={{fn (mut this.editedContent)}}
      @mode="html"
    />

    {{#each this.errors as |error|}}
      <div class="validation-error">
        {{d-icon "xmark"}}
        <b>{{error.setting}}</b>:
        {{error.errorMessage}}
      </div>
    {{/each}}
  </div>

  <div class="buttons">
    <DButton
      @action={{this.save}}
      id="save"
      class="btn-primary save"
      @disabled={{this.saveButtonDisabled}}
      @translatedLabel={{i18n "admin.customize.theme.save"}}
    />
  </div>
</div>