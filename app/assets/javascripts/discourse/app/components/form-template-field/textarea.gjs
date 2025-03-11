<div class="control-group form-template-field" data-field-type="textarea">
  {{#if @attributes.label}}
    <label class="form-template-field__label">
      {{@attributes.label}}
      {{#if @validations.required}}
        {{d-icon "asterisk" class="form-template-field__required-indicator"}}
      {{/if}}
    </label>
  {{/if}}

  {{#if @attributes.description}}
    <span class="form-template-field__description">
      {{html-safe @attributes.description}}
    </span>
  {{/if}}

  <Textarea
    name={{@id}}
    @value={{@value}}
    class="form-template-field__textarea"
    placeholder={{@attributes.placeholder}}
    pattern={{@validations.pattern}}
    minlength={{@validations.minimum}}
    maxlength={{@validations.maximum}}
    required={{if @validations.required "required" ""}}
  />
</div>