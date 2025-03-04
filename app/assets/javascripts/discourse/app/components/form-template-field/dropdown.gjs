import dIcon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import eq from "truth-helpers/helpers/eq";
<template>
  <div class="control-group form-template-field" data-field-type="dropdown">
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

    <select
      name={{@id}}
      class="form-template-field__dropdown"
      required={{if @validations.required "required" ""}}
    >
      {{#if @attributes.none_label}}
        <option
          class="form-template-field__dropdown-placeholder"
          value
          disabled
          selected
          hidden
        >{{@attributes.none_label}}</option>
      {{/if}}
      {{#each @choices as |choice|}}
        <option
          value={{choice}}
          selected={{eq @value choice}}
        >{{choice}}</option>
      {{/each}}
    </select>
  </div>
</template>
