import { Input } from "@ember/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import DInputTip from "discourse/ui-kit/d-input-tip";
import { i18n } from "discourse-i18n";
import UserFieldBase from "./base";

export default class UserFieldDate extends UserFieldBase {
  <template>
    <div class="controls">
      <Input
        id={{concat "user-" this.elementId}}
        @type="date"
        @value={{this.value}}
      />
      <label
        class="control-label alt-placeholder"
        for={{concat "user-" this.elementId}}
      >
        {{this.field.name}}
        {{~#unless this.field.required}}
          {{i18n "user_fields.optional"}}{{/unless~}}
      </label>
      {{#if this.validation.failed}}
        <DInputTip @validation={{this.validation}} />
      {{else}}
        <div class="instructions">{{trustHTML this.field.description}}</div>
      {{/if}}
    </div>
  </template>
}
