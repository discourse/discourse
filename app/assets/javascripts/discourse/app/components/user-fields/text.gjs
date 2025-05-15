import { Input } from "@ember/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import InputTip from "discourse/components/input-tip";
import { i18n } from "discourse-i18n";
import UserFieldBase from "./base";

export default class UserFieldText extends UserFieldBase {
  <template>
    <div class="controls">
      <Input
        id={{concat "user-" this.elementId}}
        @value={{this.value}}
        maxlength={{this.site.user_field_max_length}}
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
        <InputTip @validation={{this.validation}} />
      {{else}}
        <div class="instructions">{{htmlSafe this.field.description}}</div>
      {{/if}}
    </div>
  </template>
}
