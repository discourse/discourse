import { hash } from "@ember/helper";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class ChoicesField extends BaseField {
  <template>
    <div class="field control-group">
      <DAFieldLabel @label={{@label}} @field={{@field}} />

      <div class="controls">
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
}
