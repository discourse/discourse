import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

function pillClass(item) {
  if (item.isInvalid) {
    return "is-invalid";
  }
  if (item.isUsed) {
    return "is-used";
  }
  return null;
}

function pillTitle(item) {
  if (item.isInvalid) {
    return i18n("admin.site_text.interpolation_key_invalid");
  }
  if (item.isUsed) {
    return i18n("admin.site_text.interpolation_key_used");
  }
  return i18n("admin.site_text.interpolation_key_insert");
}

<template>
  {{#if @keys.length}}
    <div class="interpolation-keys">
      {{#each @keys as |item|}}
        {{#if item.isInvalid}}
          <span
            class={{concatClass "interpolation-keys__pill" (pillClass item)}}
            title={{pillTitle item}}
          >
            {{item.key}}
          </span>
        {{else}}
          <button
            type="button"
            class={{concatClass "interpolation-keys__pill" (pillClass item)}}
            title={{pillTitle item}}
            {{on "click" (fn @onInsertKey item.key)}}
          >
            {{item.key}}
          </button>
        {{/if}}
      {{/each}}
    </div>
  {{/if}}
</template>
