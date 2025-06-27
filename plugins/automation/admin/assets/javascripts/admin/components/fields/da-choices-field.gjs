import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import MultiSelect from "select-kit/components/multi-select";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class ChoicesField extends BaseField {
  @action
  onChangeChoices(choices) {
    if (isBlank(choices)) {
      choices = undefined;
    }

    this.mutValue(choices);
  }

  <template>
    <div class="field control-group">
      <DAFieldLabel @label={{@label}} @field={{@field}} />

      <div class="controls">
        {{#if this.multiselect}}
          <MultiSelect
            @value={{@field.metadata.value}}
            @content={{this.replacedContent}}
            @onChange={{this.onChangeChoices}}
            @options={{hash
              allowAny=false
              clearable=true
              disabled=@field.isDisabled
            }}
          />
        {{else}}
          <ComboBox
            @value={{@field.metadata.value}}
            @content={{this.replacedContent}}
            @onChange={{this.mutValue}}
            @options={{hash
              allowAny=false
              clearable=true
              disabled=@field.isDisabled
            }}
          />
        {{/if}}

        <DAFieldDescription @description={{@description}} />
      </div>
    </div>
  </template>

  get multiselect() {
    return !!this.args.field.extra.multiselect;
  }

  get replacedContent() {
    return (this.args.field.extra.content || []).map((r) => {
      return {
        id: r.id,
        name: r.translated_name || i18n(r.name),
      };
    });
  }
}
