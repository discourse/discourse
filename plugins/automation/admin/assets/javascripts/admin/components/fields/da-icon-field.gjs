import { hash } from "@ember/helper";
import { action } from "@ember/object";
import IconPicker from "select-kit/components/icon-picker";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class DaIconField extends BaseField {
  @action
  updateIcon(value, item) {
    let iconValue = value;

    if (Array.isArray(iconValue)) {
      iconValue = iconValue[0];
    }

    if (item && typeof item === "object") {
      iconValue = item.id || iconValue;
    }

    this.mutValue(iconValue);
  }

  get iconValue() {
    return this.args.field?.metadata?.value;
  }

  <template>
    <section class="field icon-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <IconPicker
            @value={{this.iconValue}}
            @onChange={{this.updateIcon}}
            @options={{hash
              allowNone=true
              maximum=1
              disabled=@field.isDisabled
            }}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
