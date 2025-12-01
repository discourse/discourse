import { concat, fn, hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import InputTip from "discourse/components/input-tip";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";
import UserFieldBase from "./base";

export default class UserFieldDropdown extends UserFieldBase {
  <template>
    {{#if @showLabel}}
      <label
        class="control-label alt-placeholder"
        for={{concat "user-" this.elementId}}
      >
        {{this.field.name}}
        {{~#unless this.field.required}}
          {{i18n "user_fields.optional"}}{{/unless~}}
      </label>
    {{/if}}

    <div class="controls">
      <ComboBox
        @id={{concat "user-" this.elementId}}
        @content={{this.field.options}}
        @valueProperty={{null}}
        @nameProperty={{null}}
        @value={{this.value}}
        @onChange={{fn (mut this.value)}}
        @options={{hash none=this.noneLabel}}
      />
      {{#if this.validation.failed}}
        <InputTip @validation={{this.validation}} />
      {{else}}
        {{#if @showDescription}}
          <div class="instructions">{{htmlSafe this.field.description}}</div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
