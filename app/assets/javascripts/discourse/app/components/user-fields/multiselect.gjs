import { concat, fn, hash } from "@ember/helper";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import MultiSelect from "select-kit/components/multi-select";
import UserFieldBase from "./base";

export default class UserFieldMultiselect extends UserFieldBase {
  <template>
    <label
      class="control-label alt-placeholder"
      for={{concat "user-" this.elementId}}
    >
      {{this.field.name}}
      {{~#unless this.field.required}}
        {{i18n "user_fields.optional"}}{{/unless~}}
    </label>

    <div class="controls">
      <MultiSelect
        @id={{concat "user-" this.elementId}}
        @content={{this.field.options}}
        @valueProperty={{null}}
        @nameProperty={{null}}
        @value={{this.value}}
        @onChange={{fn (mut this.value)}}
        @options={{hash none=this.noneLabel}}
      />
      <div class="instructions">{{htmlSafe this.field.description}}</div>
    </div>
  </template>
}
