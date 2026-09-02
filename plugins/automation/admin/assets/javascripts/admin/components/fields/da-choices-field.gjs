import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { i18n } from "discourse-i18n";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class ChoicesField extends BaseField {
  get multiselect() {
    return !!this.args.field.extra.multiselect;
  }

  <template>
    <div class="field control-group">
      <DAFieldLabel @field={{@field}} @label={{@label}} />

      <div class="controls">
        {{#if this.multiselect}}
          <MultiSelect
            @content={{this.replacedContent}}
            @onChange={{this.onChangeChoices}}
            @options={{hash
              allowAny=false
              clearable=true
              disabled=@field.isDisabled
            }}
            @value={{@field.metadata.value}}
          />
        {{else}}
          <ComboBox
            @content={{this.replacedContent}}
            @onChange={{this.mutValue}}
            @options={{hash
              allowAny=false
              clearable=true
              disabled=@field.isDisabled
            }}
            @value={{@field.metadata.value}}
          />
        {{/if}}

        <DAFieldDescription @description={{@description}} />
      </div>
    </div>
  </template>

  get replacedContent() {
    return (this.args.field.extra.content || []).map((r) => {
      return {
        id: r.id,
        name: r.translated_name || i18n(r.name),
      };
    });
  }

  @action
  onChangeChoices(choices) {
    if (isBlank(choices)) {
      choices = undefined;
    }

    this.mutValue(choices);
  }
}
