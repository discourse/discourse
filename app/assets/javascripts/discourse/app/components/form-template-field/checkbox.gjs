import { Input } from "@ember/component";
import dIcon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
<template><div class="control-group form-template-field" data-field-type="checkbox">
  <label class="form-template-field__label">
    <Input name={{@id}} class="form-template-field__checkbox" @checked={{@value}} @type="checkbox" required={{if @validations.required "required" ""}} />
    {{@attributes.label}}
    {{#if @validations.required}}
      {{dIcon "asterisk" class="form-template-field__required-indicator"}}
    {{/if}}
  </label>

  {{#if @attributes.description}}
    <span class="form-template-field__description">
      {{htmlSafe @attributes.description}}
    </span>
  {{/if}}
</div></template>