<div class="control-group form-template-field" data-field-type="input">
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

  <Input
    name={{@id}}
    class="form-template-field__input"
    @value={{@value}}
    @type={{if @validations.type @validations.type "text"}}
    placeholder={{@attributes.placeholder}}
    required={{if @validations.required "required" ""}}
    pattern={{@validations.pattern}}
    minlength={{@validations.minimum}}
    maxlength={{@validations.maximum}}
    disabled={{@attributes.disabled}}
  />
</div>