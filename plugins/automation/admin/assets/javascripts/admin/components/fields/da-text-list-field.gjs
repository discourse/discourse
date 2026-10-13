import { hash } from "@ember/helper";
import MultiSelect from "discourse/select-kit/components/multi-select";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class TextListField extends BaseField {
  <template>
    <section class="field text-list-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <MultiSelect
            @content={{@field.metadata.value}}
            @nameProperty={{null}}
            @onChange={{this.mutValue}}
            @options={{hash allowAny=true disabled=@field.isDisabled}}
            @value={{@field.metadata.value}}
            @valueProperty={{null}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
