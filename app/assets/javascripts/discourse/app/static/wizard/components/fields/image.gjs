<label
  class={{concatClass
    "wizard-container__button wizard-container__button-upload"
    (if this.uploading "disabled")
    (if this.hasUpload "has-upload")
  }}
>
  {{#if this.uploading}}
    {{i18n "wizard.uploading"}}
  {{else}}
    {{i18n "wizard.upload"}}
  {{/if}}

  <input
    class="wizard-hidden-upload-field"
    disabled={{this.uploading}}
    type="file"
    accept="image/*"
  />
</label>

{{#if this.field.value}}
  {{component
    this.previewComponent
    field=this.field
    fieldClass=this.fieldClass
    wizard=this.wizard
  }}
{{/if}}