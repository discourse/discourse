import { Input } from "@ember/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import InputTip from "discourse/components/input-tip";
import { i18n } from "discourse-i18n";
import UserFieldBase from "./base";

export default class UserFieldConfirm extends UserFieldBase {
  <template>
    {{#if this.field.name}}
      <label class="control-label">
        {{this.field.name}}
        {{~#unless this.field.required}}
          {{i18n "user_fields.optional"}}{{/unless~}}
      </label>
    {{/if}}

    <div class="controls">
      <label class="control-label checkbox-label">
        <Input
          id={{concat "user-" this.elementId}}
          @checked={{this.value}}
          @type="checkbox"
        />
        <span>
          {{htmlSafe this.field.description}}
          {{#unless this.field.name}}{{#if this.field.required}}<span
                class="required"
              >*</span>{{/if}}{{/unless}}
        </span>
      </label>
      <InputTip
        @validation={{@validation}}
        class={{unless @validation.reason "hidden"}}
      />
    </div>
  </template>
}
