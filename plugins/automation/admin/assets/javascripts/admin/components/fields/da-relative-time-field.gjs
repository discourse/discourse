import DRelativeTimePicker from "discourse/ui-kit/d-relative-time-picker";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class RelativeTimeField extends BaseField {
  <template>
    <section class="field text-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <div class="field-wrapper">
            <DRelativeTimePicker
              @durationMinutes={{@field.metadata.value}}
              @onChange={{this.mutValue}}
            />

            <DAFieldDescription @description={{@description}} />
          </div>
        </div>
      </div>
    </section>
  </template>
}
