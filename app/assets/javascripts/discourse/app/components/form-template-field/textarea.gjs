import dIcon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { Textarea } from "@ember/component";
<template><div class="control-group form-template-field" data-field-type="textarea">
  {{#if @attributes.label}}
    <label class="form-template-field__label">
      {{@attributes.label}}
      {{#if @validations.required}}
        {{dIcon "asterisk" class="form-template-field__required-indicator"}}
      {{/if}}
    </label>
  {{/if}}

  {{#if @attributes.description}}
    <span class="form-template-field__description">
      {{htmlSafe @attributes.description}}
    </span>
  {{/if}}

  <Textarea name={{@id}} @value={{@value}} class="form-template-field__textarea" placeholder={{@attributes.placeholder}} pattern={{@validations.pattern}} minlength={{@validations.minimum}} maxlength={{@validations.maximum}} required={{if @validations.required "required" ""}} />
</div></template>